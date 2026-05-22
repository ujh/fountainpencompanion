module RubyLlmAgent
  extend ActiveSupport::Concern

  included do
    unless method_defined?(:agent_log) || private_method_defined?(:agent_log)
      define_method(:agent_log) do
        raise NotImplementedError, "#{self.class} must implement #agent_log"
      end
    end
  end

  def chat
    @chat ||= build_chat
  end

  # Use this instead of chat.ask to ensure the transcript is saved
  # before the API call, matching the old AgentTranscript behavior.
  # Pass `with:` (URL/path or array) to attach images/files for vision-capable models.
  def ask(prompt, with: nil)
    chat.add_message(role: :user, content: build_user_content(prompt, with))
    save_transcript
    chat.complete
  end

  # Like ask, but forces the LLM to produce a halting tool call.
  # tool_choice: required only forces the first response to include a tool call,
  # but after that RubyLLM resets it. If the LLM calls a non-halting tool first
  # and then responds with text, we retry with a nudge message.
  def ask!(prompt, with: nil)
    chat.add_message(role: :user, content: build_user_content(prompt, with))
    save_transcript
    chat.with_tool(nil, choice: :required)
    result = chat.complete

    MAX_DECISION_RETRIES.times do
      break if result.is_a?(RubyLLM::Tool::Halt)

      chat.add_message(
        role: :user,
        content:
          "You must make a decision by calling one of the available decision tools. Do not respond with text."
      )
      save_transcript
      chat.with_tool(nil, choice: :required)
      result = chat.complete
    end

    unless result.is_a?(RubyLLM::Tool::Halt)
      raise DecisionNotReachedError,
            "#{self.class.name} failed to reach a decision after #{MAX_DECISION_RETRIES} retries"
    end

    result
  end

  def find_or_create_agent_log(owner)
    @agent_log ||= owner.agent_logs.processing.where(name: self.class.name).first
    @agent_log ||= owner.agent_logs.create!(name: self.class.name, transcript: [])
  end

  private

  # Wraps text + optional attachments into a RubyLLM::Content when attachments
  # are present, otherwise returns the plain string. Attachments may be a single
  # URL/path or an array.
  def build_user_content(prompt, with)
    attachments = Array(with).compact.reject { |a| a.respond_to?(:blank?) && a.blank? }
    return prompt if attachments.empty?

    RubyLLM::Content.new(prompt, attachments)
  end

  def model_id
    self.class::MODEL_ID
  end

  def system_directive
    self.class::SYSTEM_DIRECTIVE
  end

  def tools
    []
  end

  def build_chat
    c = ruby_llm_context.chat(model: model_id)
    c.with_instructions(system_directive)
    tools.each { |tool| c.with_tool(tool) }
    restore_transcript(c)
    register_callbacks(c)
    c
  end

  def ruby_llm_context
    @ruby_llm_context ||= RubyLLM.context { |config| config.openai_api_key = access_token }
  end

  def access_token
    if Rails.env.development?
      ENV.fetch("OPEN_AI_DEV_TOKEN", nil)
    else
      ENV.fetch(agent_token_env_var, ENV.fetch("OPEN_AI_TOKEN", nil))
    end
  end

  def agent_token_env_var
    "OPEN_AI_#{self.class.name.underscore.upcase}_TOKEN"
  end

  MAX_TOOL_CALLS = 50
  MAX_DECISION_RETRIES = 3

  class DecisionNotReachedError < StandardError
  end

  # Multiple saves per round-trip are intentional: we save after each
  # interaction so the agent log reflects progress incrementally.
  def register_callbacks(c)
    @tool_call_count = 0
    c.on_end_message { |message| save_transcript_and_usage(message) }
    c.on_tool_call do
      @tool_call_count += 1
      raise "Max tool calls (#{MAX_TOOL_CALLS}) exceeded" if @tool_call_count > MAX_TOOL_CALLS
      save_transcript
    end
  end

  def save_transcript_and_usage(message)
    if message&.input_tokens
      agent_log.usage["model"] = message.model_id
      agent_log.usage["prompt_tokens"] += message.input_tokens.to_i
      agent_log.usage["completion_tokens"] += message.output_tokens.to_i
      agent_log.usage["total_tokens"] += message.input_tokens.to_i + message.output_tokens.to_i
    end
    save_transcript
  end

  def save_transcript
    agent_log.transcript = serialize_messages(chat.messages)
    agent_log.save!
  end

  def serialize_messages(messages)
    messages.map do |msg|
      entry = { role: msg.role.to_s, content: sanitize_for_pg(extract_text(msg.content)) }
      entry[:tool_calls] = serialize_tool_calls(msg.tool_calls) if msg.tool_call?
      entry[:tool_call_id] = msg.tool_call_id if msg.tool_result?
      entry
    end
  end

  # Attachments (RubyLLM::Content) are not persisted in the transcript — only
  # the text portion is. On resume, the original image is lost; this is
  # acceptable because resumes only continue tool loops, not re-pose the
  # original prompt.
  def extract_text(content)
    return content.text if content.respond_to?(:text)
    content.to_s
  end

  def serialize_tool_calls(tool_calls)
    tool_calls.map { |id, tc| { id: id, name: tc.name, arguments: tc.arguments } }
  end

  # PostgreSQL cannot store \u0000 (null bytes) in text/jsonb columns.
  # LLM responses occasionally contain these characters.
  def sanitize_for_pg(str)
    str.delete("\u0000")
  end

  # Restores non-system messages from a previously saved transcript,
  # allowing agents to resume interrupted conversations.
  def restore_transcript(chat)
    return if agent_log.transcript.blank?

    entries = trim_dangling_tool_calls(agent_log.transcript)

    entries.each do |entry|
      entry = entry.deep_symbolize_keys
      next if entry[:role].blank?
      next if entry[:role].to_s.in?(%w[system developer])

      attrs = { role: entry[:role].to_sym, content: entry[:content].to_s }
      attrs[:tool_call_id] = entry[:tool_call_id] if entry[:tool_call_id]
      attrs[:tool_calls] = deserialize_tool_calls(entry[:tool_calls]) if entry[:tool_calls]
      chat.add_message(attrs)
    end
  end

  # Enforce the OpenAI invariant: every tool_call_id in an assistant message
  # must be followed by a tool message with that tool_call_id. If a worker
  # crashed mid-tool-loop the saved transcript can violate this — sometimes
  # with the dangling assistant at the end (single tool_call), sometimes in
  # the middle (parallel tool_calls partially completed, or an ask! nudge
  # appended after a partial save). Walk the transcript and truncate at the
  # first assistant-with-tool_calls that is missing any response.
  def trim_dangling_tool_calls(transcript)
    entries = transcript.map(&:deep_symbolize_keys)

    entries.each_with_index do |entry, idx|
      next unless entry[:role].to_s == "assistant" && entry[:tool_calls].present?

      required_ids = entry[:tool_calls].map { |tc| tc.deep_symbolize_keys[:id] }
      later_tool_ids =
        entries[(idx + 1)..].each_with_object([]) do |e, acc|
          acc << e[:tool_call_id] if e[:role].to_s == "tool" && e[:tool_call_id]
        end

      return entries[0...idx] unless required_ids.all? { |id| later_tool_ids.include?(id) }
    end

    entries
  end

  def deserialize_tool_calls(tool_calls_array)
    tool_calls_array.to_h do |tc|
      tc = tc.deep_symbolize_keys
      [tc[:id], RubyLLM::ToolCall.new(id: tc[:id], name: tc[:name], arguments: tc[:arguments])]
    end
  end
end
