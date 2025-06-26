require "rails_helper"

RSpec.describe PenAndInkSuggester do
  let(:user) { create(:user) }
  let(:ink_kind) { "bottle" }
  let(:extra_user_input) { "Please suggest something blue" }

  # Create test data
  let!(:collected_pen_1) do
    create(:collected_pen, user: user, brand: "Pilot", model: "Custom 74", nib: "M")
  end

  let!(:collected_pen_2) do
    create(:collected_pen, user: user, brand: "LAMY", model: "Safari", nib: "F")
  end

  let!(:collected_ink_1) do
    create(
      :collected_ink,
      user: user,
      brand_name: "Pilot",
      ink_name: "Iroshizuku Kon-peki",
      kind: "bottle"
    )
  end

  let!(:collected_ink_2) do
    create(
      :collected_ink,
      user: user,
      brand_name: "Diamine",
      ink_name: "Blue Velvet",
      kind: "cartridge"
    )
  end

  subject { described_class.new(user, ink_kind, extra_user_input) }

  describe "#initialize" do
    it "creates agent with user and preferences" do
      suggester = described_class.new(user, ink_kind, extra_user_input)
      expect(suggester.agent_log.owner).to eq(user)
      expect(suggester.agent_log.name).to eq("PenAndInkSuggester")
      expect(suggester.agent_log).to be_persisted
    end

    it "works without extra user input" do
      suggester = described_class.new(user, ink_kind, nil)
      expect(suggester.agent_log.owner).to eq(user)
    end

    it "works without ink kind filter" do
      suggester = described_class.new(user, nil, extra_user_input)
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

    before do
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

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions").once
    end

    it "sends pen and ink data to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        content = body["messages"].first["content"]

        expect(content).to include("Given the following fountain pens:")
        expect(content).to include("Given the following inks:")
        expect(content).to include(collected_pen_1.brand)
        expect(content).to include(collected_ink_1.ink_name)

        true
      }
    end

    it "uses correct OpenAI model" do
      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        expect(body["model"]).to eq("gpt-4.1")
        true
      }
    end

    it "includes function definition for record_suggestion" do
      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        expect(body["tools"]).to be_present
        expect(body["tools"].first["function"]["name"]).to eq("record_suggestion")
        true
      }
    end

    context "with extra user input" do
      it "includes extra user instructions" do
        subject.perform

        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).with { |req|
          body = JSON.parse(req.body)
          expect(body["messages"].length).to eq(2)
          expect(body["messages"].last["content"]).to include("Please suggest something blue")
          true
        }
      end
    end

    context "without extra user input" do
      subject { described_class.new(user, ink_kind, nil) }

      it "sends only main prompt" do
        subject.perform

        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).with { |req|
          body = JSON.parse(req.body)
          expect(body["messages"].length).to eq(1)
          true
        }
      end
    end

    context "with ink kind filter" do
      it "filters inks by specified kind" do
        subject.perform

        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]
          expect(content).to include(collected_ink_1.ink_name) # bottle
          expect(content).not_to include(collected_ink_2.ink_name) # cartridge
          true
        }
      end
    end

    context "without ink kind filter" do
      subject { described_class.new(user, nil, extra_user_input) }

      it "includes all ink types" do
        subject.perform

        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]
          expect(content).to include(collected_ink_1.ink_name) # bottle
          expect(content).to include(collected_ink_2.ink_name) # cartridge
          true
        }
      end
    end
  end

  describe "data formatting" do
    before do
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
        "choices" => [
          {
            "message" => {
              "tool_calls" => [
                {
                  "function" => {
                    "arguments" => {
                      "suggestion" => "Great combination!",
                      "ink_id" => collected_ink_1.id,
                      "pen_id" => collected_pen_1.id
                    }.to_json
                  }
                }
              ]
            }
          }
        ]
      }
    end

    it "sends CSV formatted data to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
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
    end

    it "includes pen and ink details for AI context" do
      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        content = body["messages"].first["content"]

        expect(content).to include("Pilot")
        expect(content).to include("Custom 74")
        expect(content).to include("Iroshizuku Kon-peki")

        true
      }
    end

    it "handles special characters in names" do
      create(:collected_pen, user: user, brand: 'Test "Brand"', model: 'Model "Special"')

      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        content = body["messages"].first["content"]
        expect(content).to include("Brand")
        expect(content).to include("Special")
        true
      }
    end

    it "excludes archived items" do
      collected_pen_1.update!(archived_on: 1.day.ago)
      collected_ink_1.update!(archived_on: 1.day.ago)

      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        content = body["messages"].first["content"]
        # Should not include archived items
        expect(content).not_to include("#{collected_pen_1.id},")
        expect(content).not_to include("#{collected_ink_1.id},")
        true
      }
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
  end

  describe "integration test" do
    let!(:micro_cluster) { create(:micro_cluster) }

    before do
      collected_ink_1.update!(micro_cluster: micro_cluster)

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
        "choices" => [
          {
            "message" => {
              "tool_calls" => [
                {
                  "function" => {
                    "arguments" => {
                      "suggestion" =>
                        "**Pilot Custom 74** with **Pilot Iroshizuku Kon-peki** is an excellent combination. The smooth medium nib pairs perfectly with this beautiful blue ink.",
                      "ink_id" => collected_ink_1.id,
                      "pen_id" => collected_pen_1.id
                    }.to_json
                  }
                }
              ]
            }
          }
        ]
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

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        content = body["messages"].first["content"]
        # Should include columns for clustering information
        expect(content).to include("tags,description")
        true
      }
    end
  end
end
