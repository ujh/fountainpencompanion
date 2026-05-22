require "rails_helper"

RSpec.describe RubyLlmAgent do
  let(:test_class) do
    Class.new do
      include RubyLlmAgent

      attr_accessor :agent_log

      def initialize(agent_log)
        self.agent_log = agent_log
      end
    end
  end

  let(:test_class_with_tools) do
    Class.new do
      include RubyLlmAgent

      attr_accessor :agent_log, :decide_tool

      def initialize(agent_log, decide_tool)
        self.agent_log = agent_log
        self.decide_tool = decide_tool
      end

      private

      def model_id = "gpt-4.1-mini"
      def system_directive = "You are a test agent."
      def tools = [decide_tool]
      def agent_token_env_var = "OPEN_AI_TOKEN"
    end
  end

  let(:decide_tool_class) do
    Class.new(RubyLLM::Tool) do
      description "Make a decision"

      def name = "decide"

      param :choice, desc: "The decision"

      def execute(choice:)
        halt "decided: #{choice}"
      end
    end
  end

  let(:search_tool_class) do
    Class.new(RubyLLM::Tool) do
      description "Search for information"

      def name = "search"

      param :query, desc: "Search query"

      def execute(query:)
        "Results for: #{query}"
      end
    end
  end

  let(:test_class_with_research_tools) do
    Class.new do
      include RubyLlmAgent

      attr_accessor :agent_log, :decide_tool, :search_tool

      def initialize(agent_log, decide_tool, search_tool)
        self.agent_log = agent_log
        self.decide_tool = decide_tool
        self.search_tool = search_tool
      end

      private

      def model_id = "gpt-4.1-mini"
      def system_directive = "You are a test agent."
      def tools = [decide_tool, search_tool]
      def agent_token_env_var = "OPEN_AI_TOKEN"
    end
  end

  let(:agent_log) { AgentLog.create!(name: "TestAgent", transcript: []) }
  let(:agent) { test_class.new(agent_log) }

  describe "#sanitize_for_pg" do
    it "strips null bytes from strings" do
      result = agent.send(:sanitize_for_pg, "hello\u0000world")
      expect(result).to eq("helloworld")
    end

    it "leaves normal strings unchanged" do
      result = agent.send(:sanitize_for_pg, "hello world")
      expect(result).to eq("hello world")
    end

    it "handles empty strings" do
      result = agent.send(:sanitize_for_pg, "")
      expect(result).to eq("")
    end

    it "strips multiple null bytes" do
      result = agent.send(:sanitize_for_pg, "\u0000foo\u0000bar\u0000")
      expect(result).to eq("foobar")
    end
  end

  describe "#trim_dangling_tool_calls" do
    it "removes the last entry if it is an assistant message with tool_calls" do
      transcript = [
        { role: "user", content: "hello" },
        {
          role: "assistant",
          content: "",
          tool_calls: [{ id: "call_1", name: "my_tool", arguments: {} }]
        }
      ]

      result = agent.send(:trim_dangling_tool_calls, transcript)
      expect(result.length).to eq(1)
      expect(result.first[:role].to_s).to eq("user")
    end

    it "does not remove the last entry if it has tool responses following" do
      transcript = [
        { role: "user", content: "hello" },
        {
          role: "assistant",
          content: "",
          tool_calls: [{ id: "call_1", name: "my_tool", arguments: {} }]
        },
        { role: "tool", content: "result", tool_call_id: "call_1" }
      ]

      result = agent.send(:trim_dangling_tool_calls, transcript)
      expect(result.length).to eq(3)
    end

    it "does not remove the last entry if it is a user message" do
      transcript = [{ role: "user", content: "hello" }]

      result = agent.send(:trim_dangling_tool_calls, transcript)
      expect(result.length).to eq(1)
    end

    it "handles an empty transcript" do
      result = agent.send(:trim_dangling_tool_calls, [])
      expect(result).to eq([])
    end

    it "works with string keys" do
      transcript = [
        { "role" => "user", "content" => "hello" },
        {
          "role" => "assistant",
          "content" => "",
          "tool_calls" => [{ "id" => "call_1", "name" => "my_tool", "arguments" => {} }]
        }
      ]

      result = agent.send(:trim_dangling_tool_calls, transcript)
      expect(result.length).to eq(1)
    end

    it "truncates at an assistant with parallel tool_calls when one response is missing" do
      transcript = [
        { role: "user", content: "hello" },
        {
          role: "assistant",
          content: "",
          tool_calls: [
            { id: "call_a", name: "my_tool", arguments: {} },
            { id: "call_b", name: "my_tool", arguments: {} }
          ]
        },
        { role: "tool", content: "result a", tool_call_id: "call_a" }
      ]

      result = agent.send(:trim_dangling_tool_calls, transcript)
      expect(result.length).to eq(1)
      expect(result.first[:role].to_s).to eq("user")
    end

    it "keeps an assistant with parallel tool_calls when all responses are present" do
      transcript = [
        { role: "user", content: "hello" },
        {
          role: "assistant",
          content: "",
          tool_calls: [
            { id: "call_a", name: "my_tool", arguments: {} },
            { id: "call_b", name: "my_tool", arguments: {} }
          ]
        },
        { role: "tool", content: "result a", tool_call_id: "call_a" },
        { role: "tool", content: "result b", tool_call_id: "call_b" }
      ]

      result = agent.send(:trim_dangling_tool_calls, transcript)
      expect(result.length).to eq(4)
    end

    it "truncates at a mid-transcript assistant whose tool response is missing" do
      transcript = [
        { role: "user", content: "hello" },
        {
          role: "assistant",
          content: "",
          tool_calls: [{ id: "call_1", name: "my_tool", arguments: {} }]
        },
        { role: "user", content: "nudge" }
      ]

      result = agent.send(:trim_dangling_tool_calls, transcript)
      expect(result.length).to eq(1)
      expect(result.first[:role].to_s).to eq("user")
    end

    it "leaves transcripts with no tool_calls untouched" do
      transcript = [
        { role: "user", content: "hello" },
        { role: "assistant", content: "hi there" },
        { role: "user", content: "thanks" }
      ]

      result = agent.send(:trim_dangling_tool_calls, transcript)
      expect(result.length).to eq(3)
    end
  end

  describe "#ask!" do
    let(:agent_with_tools) { test_class_with_tools.new(agent_log, decide_tool_class.new) }

    def tool_call_response(call_id: "call_1", name: "decide", arguments: { "choice" => "yes" })
      {
        "id" => "chatcmpl-#{call_id}",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => call_id,
                  "type" => "function",
                  "function" => {
                    "name" => name,
                    "arguments" => arguments.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 20,
          "total_tokens" => 120
        }
      }
    end

    def text_response(content: "I think the answer is yes.")
      {
        "id" => "chatcmpl-text",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => content
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 20,
          "total_tokens" => 120
        }
      }
    end

    it "succeeds when LLM calls a halting tool on first try" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: tool_call_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      result = agent_with_tools.ask!("Make a decision")
      expect(result).to be_a(RubyLLM::Tool::Halt)
      expect(result.content).to eq("decided: yes")
    end

    it "retries when LLM responds with text and succeeds on retry" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        {
          status: 200,
          body: text_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        },
        {
          status: 200,
          body: tool_call_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        }
      )

      result = agent_with_tools.ask!("Make a decision")
      expect(result).to be_a(RubyLLM::Tool::Halt)
    end

    it "saves transcript after adding nudge message" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        {
          status: 200,
          body: text_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        },
        {
          status: 200,
          body: tool_call_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        }
      )

      agent_with_tools.ask!("Make a decision")

      nudge_messages =
        agent_log.reload.transcript.select do |msg|
          msg["role"] == "user" && msg["content"].include?("decision tools")
        end
      expect(nudge_messages.length).to eq(1)
    end

    it "raises DecisionNotReachedError after max retries" do
      stub =
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: text_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )

      expect { agent_with_tools.ask!("Make a decision") }.to raise_error(
        RubyLlmAgent::DecisionNotReachedError
      )
      # 1 initial + 3 retries = 4 total requests
      expect(stub).to have_been_requested.times(4)
    end

    it "retries when LLM calls a non-halting tool then responds with text" do
      agent =
        test_class_with_research_tools.new(agent_log, decide_tool_class.new, search_tool_class.new)

      search_response =
        tool_call_response(call_id: "call_search", name: "search", arguments: { "query" => "test" })

      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        # First call: LLM calls the non-halting search tool
        {
          status: 200,
          body: search_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        },
        # After search result, LLM responds with text instead of deciding
        {
          status: 200,
          body: text_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        },
        # Retry: LLM calls the halting decide tool
        {
          status: 200,
          body: tool_call_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        }
      )

      result = agent.ask!("Make a decision")
      expect(result).to be_a(RubyLLM::Tool::Halt)
    end
  end

  describe "#ask with attachments" do
    let(:agent_with_tools) { test_class_with_tools.new(agent_log, decide_tool_class.new) }

    def text_completion
      {
        "id" => "chatcmpl-attach",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "ok"
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 10,
          "completion_tokens" => 5,
          "total_tokens" => 15
        }
      }
    end

    it "sends a multipart user message when `with:` is a URL" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: text_completion.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      agent_with_tools.ask("Describe this", with: "https://example.com/img.jpg")

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        user_msg = body["messages"].find { |m| m["role"] == "user" }
        parts = user_msg["content"]
        parts.is_a?(Array) && parts.any? { |p| p["type"] == "image_url" } &&
          parts.any? { |p| p["type"] == "text" }
      }
    end

    it "sends a multipart user message when `with:` is an array of URLs" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: text_completion.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      agent_with_tools.ask(
        "Describe these",
        with: %w[https://example.com/a.jpg https://example.com/b.jpg]
      )

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        user_msg = body["messages"].find { |m| m["role"] == "user" }
        parts = user_msg["content"]
        parts.is_a?(Array) && parts.count { |p| p["type"] == "image_url" } == 2
      }
    end

    it "sends a plain string user message when `with:` is nil" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: text_completion.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      agent_with_tools.ask("Just text")

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        user_msg = body["messages"].find { |m| m["role"] == "user" }
        user_msg["content"] == "Just text"
      }
    end

    it "sends a plain string user message when `with:` is blank" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: text_completion.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      agent_with_tools.ask("Just text", with: "")

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        user_msg = body["messages"].find { |m| m["role"] == "user" }
        user_msg["content"] == "Just text"
      }
    end

    it "persists only the text portion of an attachment message in the transcript" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: text_completion.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      agent_with_tools.ask("Describe this", with: "https://example.com/img.jpg")

      user_entry = agent_log.reload.transcript.find { |m| m["role"] == "user" }
      expect(user_entry["content"]).to eq("Describe this")
    end
  end
end
