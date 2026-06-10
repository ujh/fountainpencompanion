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

  describe "rejected suggestions in the user prompt" do
    it "embeds the validated {ink_id, pen_id} pairs as JSON" do
      pairs = [{ ink_id: 1, pen_id: 2 }, { ink_id: 3, pen_id: 4 }]
      suggester = described_class.new(user, nil, pairs)
      prompt = suggester.send(:user_prompt)

      expect(prompt).to include('"ink_id":1')
      expect(prompt).to include('"pen_id":4')
      expect(prompt).to include("rejected. Do not recommend them again")
    end

    it "does not include the section when no pairs are passed" do
      suggester = described_class.new(user, nil, [])
      prompt = suggester.send(:user_prompt)
      expect(prompt).not_to include("rejected")
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
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

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

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          body["tools"]&.present? && body["tools"].first["function"]["name"] == "record_suggestion"
        }
        .at_least_once
    end

    context "with extra user input" do
      it "includes extra user instructions in user message" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
            expect(content).to include("Please suggest something blue")
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
            content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
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

    it "sends CSV formatted data to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

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
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

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
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
          expect(content).to include("Brand")
          expect(content).to include("Special")
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
          body: { error: { message: "Internal server error" } }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises an error" do
        expect { subject.perform }.to raise_error(RubyLLM::ServerError)
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

  describe "tools" do
    describe PenAndInkSuggester::RecordSuggestion do
      let(:inks) { user.collected_inks.active }
      let(:pens) { user.collected_pens.active }

      it "has the correct name" do
        tool = described_class.new(inks, pens)
        expect(tool.name).to eq("record_suggestion")
      end

      it "records suggestion and halts on valid input" do
        tool = described_class.new(inks, pens)
        result =
          tool.call(
            suggestion: "Great combination!",
            ink_id: collected_ink_1.id,
            pen_id: collected_pen_1.id
          )

        expect(result).to be_a(RubyLLM::Tool::Halt)
        expect(tool.message).to eq("Great combination!")
        expect(tool.result_ink_id).to eq(collected_ink_1.id)
        expect(tool.result_pen_id).to eq(collected_pen_1.id)
      end

      it "returns error for invalid ink ID" do
        tool = described_class.new(inks, pens)
        result = tool.call(suggestion: "Test", ink_id: 99_999, pen_id: collected_pen_1.id)

        expect(result).to eq("Please try again. The ink ID is invalid.")
      end

      it "returns error for invalid pen ID" do
        tool = described_class.new(inks, pens)
        result = tool.call(suggestion: "Test", ink_id: collected_ink_1.id, pen_id: 99_999)

        expect(result).to eq("Please try again. The pen ID is invalid.")
      end

      it "returns error for both invalid IDs" do
        tool = described_class.new(inks, pens)
        result = tool.call(suggestion: "Test", ink_id: 99_999, pen_id: 99_999)

        expect(result).to eq("Please try again. Both the pen and ink IDs are invalid.")
      end

      it "returns error for blank suggestion" do
        tool = described_class.new(inks, pens)
        result = tool.call(suggestion: "", ink_id: collected_ink_1.id, pen_id: collected_pen_1.id)

        expect(result).to eq("Please try again. The suggestion message is blank.")
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
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
          # Should include columns for clustering information
          expect(content).to include("tags,description")
          true
        }
        .at_least_once
    end
  end

  describe "transcript and usage tracking" do
    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "updates agent log transcript" do
      subject.perform

      transcript = subject.agent_log.transcript
      expect(transcript).to be_an(Array)
      expect(transcript.length).to be >= 3
      expect(transcript.any? { |e| e["role"] == "user" }).to be true
      expect(transcript.any? { |e| e["role"] == "assistant" }).to be true
    end

    it "updates agent log usage" do
      subject.perform

      usage = subject.agent_log.usage
      expect(usage["prompt_tokens"]).to eq(150)
      expect(usage["completion_tokens"]).to eq(50)
      expect(usage["total_tokens"]).to eq(200)
      expect(usage["model"]).to eq("gpt-4.1")
    end
  end
end
