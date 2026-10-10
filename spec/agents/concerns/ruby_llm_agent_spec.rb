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

  describe "usage" do
    let(:agent) { test_class_with_tools.new(agent_log, decide_tool_class.new) }

    def completion(usage)
      {
        "id" => "chatcmpl-usage",
        "object" => "chat.completion",
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
        "usage" => usage
      }
    end

    def stub_usage(*usages)
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        *usages.map do |usage|
          {
            status: 200,
            body: completion(usage).to_json,
            headers: {
              "Content-Type" => "application/json"
            }
          }
        end
      )
    end

    it "records uncached prompt tokens and, separately, cached ones" do
      stub_usage(
        {
          "prompt_tokens" => 1_500,
          "completion_tokens" => 20,
          "total_tokens" => 1_520,
          "prompt_tokens_details" => {
            "cached_tokens" => 1_024
          }
        },
        {
          "prompt_tokens" => 1_200,
          "completion_tokens" => 10,
          "total_tokens" => 1_210,
          "prompt_tokens_details" => {
            "cached_tokens" => 1_024
          }
        }
      )

      2.times { agent.ask("Hello") }

      expect(agent_log.reload.usage).to include(
        "prompt_tokens" => 476 + 176,
        "cached_tokens" => 2_048,
        "completion_tokens" => 30
      )
    end

    it "adds no cached count when nothing was cached" do
      stub_usage({ "prompt_tokens" => 100, "completion_tokens" => 5, "total_tokens" => 105 })

      agent.ask("Hello")

      expect(agent_log.reload.usage).not_to have_key("cached_tokens")
      expect(agent_log.usage["prompt_tokens"]).to eq(100)
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

  describe "tool call limit" do
    def parallel_search_response(count)
      {
        "id" => "chatcmpl-parallel",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" =>
                Array.new(count) do |i|
                  {
                    "id" => "call_#{i}",
                    "type" => "function",
                    "function" => {
                      "name" => "search",
                      "arguments" => { "query" => "q#{i}" }.to_json
                    }
                  }
                end
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

    def final_text_response
      {
        "id" => "chatcmpl-final",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "done"
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 5,
          "total_tokens" => 105
        }
      }
    end

    def stub_responses(*responses)
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        *responses.map do |response|
          { status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" } }
        end
      )
    end

    let(:search_agent_class) do
      Class.new do
        include RubyLlmAgent

        attr_accessor :agent_log, :search_tool

        def initialize(agent_log, search_tool)
          self.agent_log = agent_log
          self.search_tool = search_tool
        end

        private

        def model_id = "gpt-4.1-mini"
        def system_directive = "You are a test agent."
        def tools = [search_tool]
        def agent_token_env_var = "OPEN_AI_TOKEN"
      end
    end

    let(:capped_agent_class) { Class.new(search_agent_class) { private def max_tool_calls = 2 } }

    it "defaults to 50 tool calls" do
      agent = search_agent_class.new(agent_log, search_tool_class.new)

      expect(agent.send(:max_tool_calls)).to eq(50)
    end

    it "allows exactly the default number of tool calls" do
      stub_responses(parallel_search_response(50), final_text_response)
      agent = search_agent_class.new(agent_log, search_tool_class.new)

      expect(agent.ask("Search").content).to eq("done")
    end

    it "raises ToolCallLimitExceeded when the default limit is passed" do
      stub_responses(parallel_search_response(51), final_text_response)
      agent = search_agent_class.new(agent_log, search_tool_class.new)

      expect { agent.ask("Search") }.to raise_error(
        RubyLlmAgent::ToolCallLimitExceeded,
        /limit of 50 tool calls/
      )
    end

    it "counts individual tool calls across rounds" do
      stub_responses(
        parallel_search_response(1),
        parallel_search_response(1),
        parallel_search_response(1),
        final_text_response
      )
      agent = capped_agent_class.new(agent_log, search_tool_class.new)

      expect { agent.ask("Search") }.to raise_error(RubyLlmAgent::ToolCallLimitExceeded)
    end

    it "uses an overridden max_tool_calls" do
      stub_responses(parallel_search_response(3), final_text_response)
      agent = capped_agent_class.new(agent_log, search_tool_class.new)

      expect { agent.ask("Search") }.to raise_error(
        RubyLlmAgent::ToolCallLimitExceeded,
        /limit of 2 tool calls/
      )
    end

    it "allows tool calls up to an overridden max_tool_calls" do
      stub_responses(parallel_search_response(2), final_text_response)
      agent = capped_agent_class.new(agent_log, search_tool_class.new)

      expect(agent.ask("Search").content).to eq("done")
    end
  end

  describe "tool_calls_mode" do
    def decide_response
      {
        "id" => "chatcmpl-decide",
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
                  "id" => "call_1",
                  "type" => "function",
                  "function" => {
                    "name" => "decide",
                    "arguments" => { "choice" => "yes" }.to_json
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

    def text_only_response
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
              "content" => "Thinking about it."
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 5,
          "total_tokens" => 105
        }
      }
    end

    def expect_requests(times:, &body_matcher)
      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req| body_matcher.call(JSON.parse(req.body)) }
        .times(times)
    end

    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        {
          status: 200,
          body: text_only_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        },
        {
          status: 200,
          body: decide_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        }
      )
    end

    it "defaults to nil and sends no parallel_tool_calls option" do
      agent = test_class_with_tools.new(agent_log, decide_tool_class.new)

      agent.ask!("Make a decision")

      expect(agent.send(:tool_calls_mode)).to be_nil
      expect_requests(times: 2) { |body| body.key?("tools") && !body.key?("parallel_tool_calls") }
    end

    it "sends parallel_tool_calls false on every request when the mode is :one" do
      agent_class = Class.new(test_class_with_tools) { private def tool_calls_mode = :one }
      agent = agent_class.new(agent_log, decide_tool_class.new)

      agent.ask!("Make a decision")

      expect_requests(times: 2) { |body| body["parallel_tool_calls"] == false }
    end

    it "sends parallel_tool_calls true when the mode is :many" do
      agent_class = Class.new(test_class_with_tools) { private def tool_calls_mode = :many }
      agent = agent_class.new(agent_log, decide_tool_class.new)

      agent.ask!("Make a decision")

      expect_requests(times: 2) { |body| body["parallel_tool_calls"] == true }
    end

    it "registers every tool" do
      agent =
        test_class_with_research_tools.new(agent_log, decide_tool_class.new, search_tool_class.new)

      expect(agent.chat.tools.keys).to contain_exactly(:decide, :search)
    end
  end
end
