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

    it "initializes transcript with system directive" do
      summarizer = described_class.new(parent_agent_log, raw_html)
      expect(summarizer.transcript.first[:system]).to be_present
      expect(summarizer.transcript.first[:system]).to include("raw HTML of a web page")
      expect(summarizer.transcript.first[:system]).to include("summary should include")
      expect(summarizer.transcript.first[:system]).to include("title, description")
    end

    it "adds raw HTML to transcript as user message" do
      summarizer = described_class.new(parent_agent_log, raw_html)
      user_message = summarizer.transcript.find { |msg| msg[:user] }
      expect(user_message[:user]).to eq(raw_html)
    end

    context "when agent_log already has transcript" do
      let(:existing_transcript) do
        [{ system: "Existing system message" }, { user: "Existing user message" }]
      end

      before do
        allow_any_instance_of(described_class).to receive(:agent_log).and_return(
          double("agent_log", transcript: existing_transcript)
        )
      end

      it "uses existing transcript instead of creating new one" do
        summarizer = described_class.new(parent_agent_log, raw_html)
        expect(summarizer.transcript.first[:system]).to eq("Existing system message")
      end
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
          system_msg = messages.find { |msg| msg["role"] == "system" }
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
          body: { error: { message: "Internal server error" } }.to_json
        )
      end

      it "raises an error" do
        expect { subject.perform }.to raise_error(Faraday::ServerError)
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

    context "when OpenAI returns unexpected response format" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: { "id" => "chatcmpl-test", "choices" => [] }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles response without choices gracefully" do
        expect { subject.perform }.to raise_error(NoMethodError)
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

        # Verify transcript was updated
        expect(summarizer.transcript.count).to be >= 2
        expect(summarizer.transcript.any? { |msg| msg[:system] }).to be true
        expect(summarizer.transcript.any? { |msg| msg[:user] }).to be true
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
