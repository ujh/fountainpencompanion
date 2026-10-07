require "rails_helper"

RSpec.describe WebPageSummarizer do
  before(:each) { WebMock.reset! }

  let(:user) { create(:user) }
  let(:parent_agent_log) do
    AgentLog.create!(name: "ParentAgent", owner: user, state: "processing", transcript: [])
  end
  let(:raw_html) { <<~HTML }
      <!DOCTYPE html>
      <html>
      <head>
        <title>Pilot Iroshizuku Kon-peki Review</title>
        <meta name="description" content="A comprehensive review of Pilot's beautiful blue fountain pen ink">
      </head>
      <body>
        <h1>Pilot Iroshizuku Kon-peki - Deep Azure Blue</h1>
        <p>This is one of the most popular fountain pen inks from Pilot's Iroshizuku line.
           The color is a beautiful deep blue with excellent flow characteristics.</p>
        <div class="review">
          <h2>Performance</h2>
          <p>Great shading and water resistance. Perfect for daily writing.</p>
        </div>
      </body>
      </html>
    HTML

  subject { described_class.new(parent_agent_log, raw_html) }

  describe "#initialize" do
    it "creates agent with parent_agent_log and raw_html" do
      summarizer = described_class.new(parent_agent_log, raw_html)
      expect(summarizer.send(:parent_agent_log)).to eq(parent_agent_log)
      expect(summarizer.send(:raw_html)).to eq(raw_html)
    end
  end

  describe "#agent_log" do
    it "creates and memoizes agent log under parent" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to be_persisted
      expect(log1.name).to eq("WebPageSummarizer")
      expect(log1.owner).to eq(parent_agent_log)
      expect(log1.state).to eq("processing")
      expect(log1).to eq(log2)
    end

    it "finds existing processing agent log if it exists" do
      existing_log =
        parent_agent_log.agent_logs.create!(
          name: "WebPageSummarizer",
          state: "processing",
          transcript: []
        )

      expect(subject.agent_log).to eq(existing_log)
    end

    it "creates new agent log if no processing one exists" do
      parent_agent_log.agent_logs.create!(
        name: "WebPageSummarizer",
        state: "approved",
        transcript: []
      )

      new_log = subject.agent_log
      expect(new_log).to be_persisted
      expect(new_log.state).to eq("processing")
      expect(new_log).not_to eq(parent_agent_log.agent_logs.first)
    end
  end

  describe "transcript restoration" do
    let(:existing_transcript) do
      [
        { "role" => "developer", "content" => "You will be given the raw HTML of a web page." },
        { "role" => "user", "content" => "<html><body>Original HTML</body></html>" },
        { "role" => "assistant", "content" => "Previous summary attempt" }
      ]
    end
    let(:continued_response) do
      {
        "id" => "chatcmpl-continued",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "Continued summary"
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 50,
          "total_tokens" => 150
        }
      }
    end

    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: continued_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "restores messages from an existing agent log transcript" do
      parent_agent_log.agent_logs.create!(
        name: "WebPageSummarizer",
        state: "processing",
        transcript: existing_transcript
      )

      summarizer = described_class.new(parent_agent_log, raw_html)
      summarizer.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        messages = body["messages"]

        # Should have: developer (system), user (restored), assistant (restored), user (new ask)
        messages.length == 4 && messages[0]["role"] == "developer" &&
          messages[1]["role"] == "user" &&
          messages[1]["content"] == "<html><body>Original HTML</body></html>" &&
          messages[2]["role"] == "assistant" &&
          messages[2]["content"] == "Previous summary attempt" && messages[3]["role"] == "user"
      }
    end
  end

  describe "#perform" do
    let(:successful_response) do
      {
        "id" => "chatcmpl-123",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" =>
                "**Title:** Pilot Iroshizuku Kon-peki Review\n\n**Description:** A comprehensive review of Pilot's beautiful blue fountain pen ink\n\n**Summary:** This page reviews the Pilot Iroshizuku Kon-peki fountain pen ink, describing it as a deep azure blue ink with excellent flow characteristics, great shading, and water resistance, making it perfect for daily writing."
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 200,
          "completion_tokens" => 100,
          "total_tokens" => 300
        }
      }
    end

    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "makes HTTP request to OpenAI API" do
      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).at_least_once
    end

    it "sends system directive and HTML content to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          messages = body["messages"]
          system_msg = messages.find { |msg| msg["role"] == "system" || msg["role"] == "developer" }
          user_msg = messages.find { |msg| msg["role"] == "user" }

          system_msg&.dig("content")&.include?("raw HTML of a web page") &&
            user_msg&.dig("content")&.include?("<!DOCTYPE html>")
        }
        .at_least_once
    end

    it "sets agent log to waiting for approval" do
      subject.perform

      expect(subject.agent_log.reload.state).to eq("waiting-for-approval")
    end

    it "returns the summary from OpenAI" do
      result = subject.perform

      expect(result).to be_a(String)
      expect(result).to include("Pilot Iroshizuku Kon-peki Review")
      expect(result).to include("deep azure blue ink")
    end

    it "updates agent log transcript" do
      subject.perform

      transcript = subject.agent_log.transcript
      expect(transcript).to be_an(Array)
      expect(transcript.length).to be >= 3
      expect(transcript.first["role"]).to eq("system")
      expect(transcript.any? { |e| e["role"] == "user" }).to be true
      expect(transcript.any? { |e| e["role"] == "assistant" }).to be true
    end

    it "updates agent log usage" do
      subject.perform

      usage = subject.agent_log.usage
      expect(usage["prompt_tokens"]).to eq(200)
      expect(usage["completion_tokens"]).to eq(100)
      expect(usage["total_tokens"]).to eq(300)
      expect(usage["model"]).to eq("gpt-4.1-mini")
    end
  end

  describe "data formatting" do
    let(:simple_response) do
      {
        "id" => "chatcmpl-test",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "Test summary"
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 50,
          "completion_tokens" => 25,
          "total_tokens" => 75
        }
      }
    end

    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: simple_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "sends HTML content exactly as provided" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          user_message = body["messages"].find { |msg| msg["role"] == "user" }
          user_message["content"] == raw_html
        }
        .at_least_once
    end

    it "handles HTML with special characters" do
      special_html = "<p>Price: $100 & worth it! 50% off — great deal</p>"
      summarizer = described_class.new(parent_agent_log, special_html)

      summarizer.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          user_message = body["messages"].find { |msg| msg["role"] == "user" }
          user_message["content"] == special_html
        }
        .at_least_once
    end

    it "truncates HTML longer than the input limit" do
      long_html = "<p>#{"a" * described_class::MAX_INPUT_CHARS}</p>"
      described_class.new(parent_agent_log, long_html).perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          user_message = body["messages"].find { |msg| msg["role"] == "user" }
          user_message["content"] == long_html[0, described_class::MAX_INPUT_CHARS]
        }
        .at_least_once
    end

    it "handles empty HTML content" do
      empty_html = ""
      summarizer = described_class.new(parent_agent_log, empty_html)

      summarizer.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          user_message = body["messages"].find { |msg| msg["role"] == "user" }
          user_message["content"] == ""
        }
        .at_least_once
    end
  end

  describe "error handling" do
    context "when OpenAI API returns 500 error" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 500,
          body: "Internal Server Error"
        )
      end

      it "raises an error" do
        expect { subject.perform }.to raise_error(RubyLLM::ServerError)
      end
    end

    context "when OpenAI returns malformed JSON" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: "invalid json",
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises a parsing error" do
        expect { subject.perform }.to raise_error(Faraday::ParsingError)
      end
    end

    context "when network request fails" do
      before { stub_request(:post, "https://api.openai.com/v1/chat/completions").to_timeout }

      it "raises a timeout error" do
        expect { subject.perform }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe "integration scenarios" do
    context "complete summarization workflow" do
      let(:full_response) do
        {
          "id" => "chatcmpl-workflow-test",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1-mini",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" =>
                  "**Title:** Pilot Iroshizuku Kon-peki Review\n\n**Description:** A comprehensive review of Pilot's beautiful blue fountain pen ink featuring detailed analysis of its color, flow, and performance characteristics.\n\n**Key Information:**\n- Product: Pilot Iroshizuku Kon-peki fountain pen ink\n- Color: Deep azure blue\n- Performance: Excellent flow, great shading, water resistant\n- Use case: Perfect for daily writing and special occasions\n\n**Summary:** This webpage provides an in-depth review of the popular Pilot Iroshizuku Kon-peki fountain pen ink, highlighting its beautiful deep blue color, excellent flow characteristics, shading properties, and water resistance that make it suitable for both everyday use and special writing occasions."
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => {
            "prompt_tokens" => 180,
            "completion_tokens" => 120,
            "total_tokens" => 300
          }
        }
      end

      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: full_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "completes full summarization workflow" do
        summarizer = described_class.new(parent_agent_log, raw_html)

        # Verify initial state
        expect(summarizer.agent_log.state).to eq("processing")

        # Perform summarization
        result = summarizer.perform

        # Verify result
        expect(result).to include("Pilot Iroshizuku Kon-peki Review")
        expect(result).to include("Deep azure blue")
        expect(result).to include("excellent flow")

        # Verify agent log state change
        expect(summarizer.agent_log.reload.state).to eq("waiting-for-approval")
        expect(summarizer.agent_log.owner).to eq(parent_agent_log)
        expect(summarizer.agent_log.name).to eq("WebPageSummarizer")
      end
    end

    context "with minimal HTML content" do
      let(:minimal_html) do
        "<html><head><title>Test</title></head><body><p>Simple content</p></body></html>"
      end
      let(:minimal_response) do
        {
          "id" => "chatcmpl-minimal",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1-mini",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" =>
                  "**Title:** Test\n\n**Content:** Simple content\n\n**Summary:** A basic webpage with minimal content."
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => {
            "prompt_tokens" => 80,
            "completion_tokens" => 40,
            "total_tokens" => 120
          }
        }
      end

      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: minimal_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles minimal HTML content scenarios" do
        summarizer = described_class.new(parent_agent_log, minimal_html)
        result = summarizer.perform

        expect(result).to include("Test")
        expect(result).to include("Simple content")
        expect(summarizer.agent_log.reload.state).to eq("waiting-for-approval")
      end
    end
  end

  describe "system directive" do
    it "includes proper instructions for web page summarization" do
      expect(described_class::SYSTEM_DIRECTIVE).to include("raw HTML of a web page")
      expect(described_class::SYSTEM_DIRECTIVE).to include("summarize the page")
      expect(described_class::SYSTEM_DIRECTIVE).to include("human-readable format")
      expect(described_class::SYSTEM_DIRECTIVE).to include("title, description")
      expect(described_class::SYSTEM_DIRECTIVE).to include("relevant information")
    end
  end
end
