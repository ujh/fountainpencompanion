require "rails_helper"

RSpec.describe PenAndInkSuggester do
  before(:each) { WebMock.reset! }
  let(:user) { create(:user) }

  let(:extra_user_input) { "Please suggest something blue" }

  # Create test data
  let!(:collected_pen_1) do
    create(:collected_pen, user: user, brand: "Pilot", model: "Custom 74", nib: "M")
  end

  let!(:collected_pen_2) do
    create(:collected_pen, user: user, brand: "LAMY", model: "Safari", nib: "F")
  end

  let!(:collected_ink_1) do
    ink =
      create(
        :collected_ink,
        user: user,
        brand_name: "Pilot",
        ink_name: "Iroshizuku Kon-peki",
        kind: "bottle"
      )
    # Ensure ink has proper cluster data to avoid nil errors
    macro_cluster = create(:macro_cluster, tags: %w[blue water-based])
    micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
    ink.update!(micro_cluster: micro_cluster)
    ink
  end

  let!(:collected_ink_2) do
    ink =
      create(
        :collected_ink,
        user: user,
        brand_name: "Diamine",
        ink_name: "Blue Velvet",
        kind: "cartridge"
      )
    # Ensure ink has proper cluster data to avoid nil errors
    macro_cluster = create(:macro_cluster, tags: %w[blue cartridge])
    micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
    ink.update!(micro_cluster: micro_cluster)
    ink
  end

  subject { described_class.new(user, extra_user_input) }

  describe "#initialize" do
    it "creates agent with user and preferences" do
      suggester = described_class.new(user, extra_user_input)
      expect(suggester.agent_log.owner).to eq(user)
      expect(suggester.agent_log.name).to eq("PenAndInkSuggester")
      expect(suggester.agent_log).to be_persisted
    end

    it "works without extra user input" do
      suggester = described_class.new(user, nil)
      expect(suggester.agent_log.owner).to eq(user)
    end
  end

  describe "#agent_log" do
    it "creates and memoizes agent log" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to be_persisted
      expect(log1.name).to eq("PenAndInkSuggester")
      expect(log1.owner).to eq(user)
      expect(log1).to eq(log2)
    end
  end

  describe "#perform" do
    let(:successful_openai_response) do
      {
        "id" => "chatcmpl-123",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_123",
                  "type" => "function",
                  "function" => {
                    "name" => "record_suggestion",
                    "arguments" => {
                      "suggestion" =>
                        "**Pilot Custom 74** with **Pilot Iroshizuku Kon-peki** is an excellent combination. The smooth medium nib pairs perfectly with this beautiful blue ink.",
                      "ink_id" => collected_ink_1.id,
                      "pen_id" => collected_pen_1.id
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 150,
          "completion_tokens" => 50,
          "total_tokens" => 200
        }
      }
    end

    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "returns successful response with suggestion" do
      response = subject.perform

      expect(response[:message]).to include("Pilot Custom 74")
      expect(response[:message]).to include("Pilot Iroshizuku Kon-peki")
      expect(response[:ink]).to eq(collected_ink_1.id)
      expect(response[:pen]).to eq(collected_pen_1.id)
    end

    it "updates agent log appropriately" do
      response = subject.perform

      expect(subject.agent_log.extra_data).to eq(response.stringify_keys)
      expect(subject.agent_log.state).to eq("waiting-for-approval")
    end

    it "makes HTTP request to OpenAI API" do
      subject.perform

      # Allow for 1 or 2 requests since Raix might retry without tools
      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).at_least_once
    end

    it "sends pen and ink data to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]

          expect(content).to include("Given the following fountain pens:")
          expect(content).to include("Given the following inks:")
          expect(content).to include(collected_pen_1.brand)
          expect(content).to include(collected_ink_1.ink_name)

          true
        }
        .at_least_once
    end

    it "includes function definition for record_suggestion" do
      subject.perform

      # Check that at least one request includes the tools parameter
      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          body["tools"]&.present? && body["tools"].first["function"]["name"] == "record_suggestion"
        }
        .at_least_once
    end

    context "with extra user input" do
      it "includes extra user instructions" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            expect(body["messages"].length).to eq(2)
            expect(body["messages"].last["content"]).to include("Please suggest something blue")
            true
          }
          .at_least_once
      end
    end

    context "without extra user input" do
      subject { described_class.new(user, nil) }

      it "sends only main prompt" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            expect(body["messages"].length).to eq(1)
            true
          }
          .at_least_once
      end
    end

    context "includes all ink types" do
      it "includes both bottle and cartridge inks" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            content = body["messages"].first["content"]
            expect(content).to include(collected_ink_1.ink_name) # bottle
            expect(content).to include(collected_ink_2.ink_name) # cartridge
            true
          }
          .at_least_once
      end
    end
  end

  describe "data formatting" do
    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    let(:successful_openai_response) do
      {
        "id" => "chatcmpl-456",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_456",
                  "type" => "function",
                  "function" => {
                    "name" => "record_suggestion",
                    "arguments" => {
                      "suggestion" => "Great combination!",
                      "ink_id" => collected_ink_1.id,
                      "pen_id" => collected_pen_1.id
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 150,
          "completion_tokens" => 50,
          "total_tokens" => 200
        }
      }
    end

    it "sends CSV formatted data to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]

          # Should contain CSV headers
          expect(content).to include("pen id,fountain pen name")
          expect(content).to include("ink id,ink name")

          # Should contain usage tracking columns
          expect(content).to include("usage count,daily usage count")
          expect(content).to include("last usage")

          # Should contain actual data
          expect(content).to include(collected_pen_1.id.to_s)
          expect(content).to include(collected_ink_1.id.to_s)

          true
        }
        .at_least_once
    end

    it "includes pen and ink details for AI context" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]

          expect(content).to include("Pilot")
          expect(content).to include("Custom 74")
          expect(content).to include("Iroshizuku Kon-peki")

          true
        }
        .at_least_once
    end

    it "handles special characters in names" do
      create(:collected_pen, user: user, brand: 'Test "Brand"', model: 'Model "Special"')

      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]
          expect(content).to include("Brand")
          expect(content).to include("Special")
          true
        }
        .at_least_once
    end

    it "excludes archived items" do
      collected_pen_1.update!(archived_on: 1.day.ago)
      collected_ink_1.update!(archived_on: 1.day.ago)

      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]
          # Should not include archived items
          expect(content).not_to include("#{collected_pen_1.id},")
          expect(content).not_to include("#{collected_ink_1.id},")
          true
        }
        .at_least_once
    end
  end

  describe "error handling" do
    context "when OpenAI API returns 500 error" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 500,
          body: "Internal Server Error"
        )
      end

      it "raises an error" do
        expect { subject.perform }.to raise_error(Faraday::ServerError)
      end
    end

    context "when OpenAI returns malformed JSON" do
      before(:each) do
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
  end

  describe "integration test" do
    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    let(:successful_openai_response) do
      {
        "id" => "chatcmpl-789",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_789",
                  "type" => "function",
                  "function" => {
                    "name" => "record_suggestion",
                    "arguments" => {
                      "suggestion" =>
                        "**Pilot Custom 74** with **Pilot Iroshizuku Kon-peki** is an excellent combination. The smooth medium nib pairs perfectly with this beautiful blue ink.",
                      "ink_id" => collected_ink_1.id,
                      "pen_id" => collected_pen_1.id
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 150,
          "completion_tokens" => 50,
          "total_tokens" => 200
        }
      }
    end

    it "completes full suggestion workflow" do
      response = subject.perform

      expect(response[:message]).to include("Pilot Custom 74")
      expect(response[:message]).to include("Pilot Iroshizuku Kon-peki")
      expect(response[:ink]).to eq(collected_ink_1.id)
      expect(response[:pen]).to eq(collected_pen_1.id)
      expect(subject.agent_log.state).to eq("waiting-for-approval")
    end

    it "includes clustering data for AI context" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]
          # Should include columns for clustering information
          expect(content).to include("tags,description")
          true
        }
        .at_least_once
    end
  end
end
