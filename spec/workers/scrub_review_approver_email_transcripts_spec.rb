require "rails_helper"

describe ScrubReviewApproverEmailTranscripts do
  it "scrubs submitter emails from stored ReviewApprover transcripts" do
    ink_review = create(:ink_review)
    log =
      ink_review.agent_logs.create!(
        name: "ReviewApprover",
        transcript: [{ "role" => "user", "content" => { user: "jane@example.com" }.to_json }]
      )

    described_class.new.perform

    expect(log.reload.transcript[0]["content"]).to eq({ user: "user" }.to_json)
  end
end
