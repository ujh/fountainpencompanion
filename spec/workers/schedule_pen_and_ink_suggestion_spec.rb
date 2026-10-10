require "rails_helper"

describe SchedulePenAndInkSuggestion do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, confirmed_at: 1.month.ago) }
  let(:suggestion_id) { SecureRandom.uuid }
  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

  after { travel_back }

  it "runs on the interactive queue" do
    expect(described_class.get_sidekiq_options["queue"]).to eq("interactive")
  end

  it "is never retried" do
    expect(described_class.get_sidekiq_options["retry"]).to eq(0)
  end

  describe "result" do
    let(:suggester) { instance_double(PenAndInkSuggester) }

    before { allow(PenAndInkSuggester).to receive(:new).and_return(suggester) }

    it "writes the suggester's result to the cache" do
      allow(suggester).to receive(:perform).and_return({ message: "Use it", ink: 1, pen: 2 })

      described_class.new.perform(user.id, suggestion_id)

      expect(Rails.cache.read(suggestion_id)).to eq({ message: "Use it", ink: 1, pen: 2 })
    end

    it "writes an error result with a message and re-raises when the suggester fails" do
      allow(suggester).to receive(:perform).and_raise(RubyLLM::ServerError, "Internal server error")

      expect { described_class.new.perform(user.id, suggestion_id) }.to raise_error(
        RubyLLM::ServerError
      )
      expect(Rails.cache.read(suggestion_id)).to eq(
        { message: PenAndInkSuggester::ERROR_MESSAGE, status: "error" }
      )
    end

    it "writes an error result with a message and re-raises when the user is gone" do
      expect { described_class.new.perform(-1, suggestion_id) }.to raise_error(
        ActiveRecord::RecordNotFound
      )
      expect(Rails.cache.read(suggestion_id)).to eq(
        { message: PenAndInkSuggester::ERROR_MESSAGE, status: "error" }
      )
    end
  end

  describe "queue time" do
    let(:suggester) { instance_double(PenAndInkSuggester, perform: { message: "Use it" }) }

    before do
      freeze_time
      allow(PenAndInkSuggester).to receive(:new).and_return(suggester)
    end

    def perform_enqueued_at(enqueued_at)
      described_class.new.perform(user.id, suggestion_id, nil, [], enqueued_at)
    end

    it "passes the milliseconds since enqueueing to the suggester" do
      perform_enqueued_at(2.5.seconds.ago.to_f)

      expect(PenAndInkSuggester).to have_received(:new).with(user, nil, [], queue_ms: 2500)
    end

    it "never reports a negative queue time" do
      perform_enqueued_at(1.second.from_now.to_f)

      expect(PenAndInkSuggester).to have_received(:new).with(user, nil, [], queue_ms: 0)
    end

    it "passes no queue time for jobs enqueued without an enqueue time" do
      described_class.new.perform(user.id, suggestion_id, nil, [])

      expect(PenAndInkSuggester).to have_received(:new).with(user, nil, [], queue_ms: nil)
    end
  end

  describe "extra user input gate" do
    let(:suggester) { instance_double(PenAndInkSuggester, perform: { message: "Use it" }) }
    let(:input) { "Only samples please" }
    let(:forwarded_inputs) { [] }

    before do
      allow(PenAndInkSuggester).to receive(:new) do |_user, extra_user_input, *|
        forwarded_inputs << extra_user_input
        suggester
      end
    end

    def forwarded_input
      described_class.new.perform(user.id, suggestion_id, input, [])
      forwarded_inputs.sole
    end

    it "forwards the input when the instruction gate allows it" do
      create_list(:collected_ink, 21, user:)

      expect(forwarded_input).to eq(input)
    end

    it "drops the input when the instruction gate does not allow it" do
      create_list(:collected_ink, 20, user:)

      expect(forwarded_input).to be_nil
    end
  end

  context "when the LLM request fails" do
    before do
      create(:collected_pen, user:, brand: "Pilot", model: "Custom 74", nib: "M")
      create(:collected_ink, user:, brand_name: "Pilot", ink_name: "Kon-peki", kind: "bottle")
      stub_request(:post, openai_url).to_return(
        status: 500,
        body: { error: { message: "Internal server error" } }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "re-raises the error and counts a single run toward the daily cap" do
      expect { described_class.new.perform(user.id, suggestion_id) }.to raise_error(
        RubyLLM::ServerError
      ).and change { user.agent_logs.where(name: "PenAndInkSuggester").count }.by(1)
    end

    it "leaves an error result with a message for the widget" do
      expect { described_class.new.perform(user.id, suggestion_id) }.to raise_error(
        RubyLLM::ServerError
      )

      expect(Rails.cache.read(suggestion_id)).to eq(
        { message: PenAndInkSuggester::ERROR_MESSAGE, status: "error" }
      )
    end
  end

  context "when the suggestion succeeds" do
    let!(:pen) { create(:collected_pen, user:, brand: "Pilot", model: "Custom 74", nib: "M") }
    let!(:ink) do
      create(:collected_ink, user:, brand_name: "Pilot", ink_name: "Kon-peki", kind: "bottle")
    end

    before do
      stub_request(:post, openai_url).to_return(
        status: 200,
        body: {
          "id" => "chatcmpl-1",
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
                      "name" => "record_suggestion",
                      "arguments" => { pen_ref: "P1", ink_ref: "I1", reasoning: "Ink it" }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 10,
            "completion_tokens" => 5,
            "total_tokens" => 15
          }
        }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "records the queue time in the agent log but not in the cached result" do
      freeze_time
      described_class.new.perform(user.id, suggestion_id, nil, [], 1.second.ago.to_f)

      log = user.agent_logs.find_by!(name: "PenAndInkSuggester")
      expect(log.extra_data["queue_ms"]).to eq(1000)
      cached = Rails.cache.read(suggestion_id)
      expect(cached.keys).to eq(%i[message ink pen])
      expect(cached).to include(ink: ink.id, pen: pen.id)
      expect(cached[:message]).to end_with("\n\nInk it")
    end
  end
end
