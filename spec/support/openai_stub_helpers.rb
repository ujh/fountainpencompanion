module OpenaiStubHelpers
  OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

  # A simple text completion response (no tool calls)
  def openai_text_response(content = "Done.", model: "gpt-4.1-mini")
    {
      "id" => "chatcmpl-text",
      "object" => "chat.completion",
      "model" => model,
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
        "prompt_tokens" => 10,
        "completion_tokens" => 5,
        "total_tokens" => 15
      }
    }
  end

  # Stub that returns a tool_call response first, then a text response for the follow-up.
  # RubyLLM auto-executes tool calls internally, so the stub must return a text response
  # on the second call to break the loop.
  def stub_openai_tool_call(tool_call_response = nil, follow_up_response: nil, **kwargs)
    tool_call_response = kwargs if tool_call_response.nil? && kwargs.any?
    follow_up_response ||= openai_text_response
    call_count = 0
    stub_request(:post, OPENAI_CHAT_URL).to_return do |_request|
      call_count += 1
      if call_count == 1
        {
          status: 200,
          body: tool_call_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        }
      else
        {
          status: 200,
          body: follow_up_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        }
      end
    end
  end

  # Stub that always returns the same response (useful for text-only or error tests)
  def stub_openai_response(response_body = nil, status: 200, **kwargs)
    response_body = kwargs if response_body.nil? && kwargs.any?
    stub_request(:post, OPENAI_CHAT_URL).to_return(
      status: status,
      body: response_body.is_a?(String) ? response_body : response_body.to_json,
      headers: {
        "Content-Type" => "application/json"
      }
    )
  end
end

RSpec.configure { |config| config.include OpenaiStubHelpers }
