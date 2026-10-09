require "rails_helper"

describe SchedulePenAndInkSuggestion do
  let(:user) { create(:user) }
  let(:suggestion_id) { SecureRandom.uuid }

  before do
    create(:collected_pen, user:, brand: "Pilot", model: "Custom 74", nib: "M")
    create(:collected_ink, user:, brand_name: "Pilot", ink_name: "Kon-peki", kind: "bottle")
  end

  it "is never retried" do
    expect(described_class.get_sidekiq_options["retry"]).to eq(0)
  end

  context "when the LLM request fails" do
    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
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
  end
end
