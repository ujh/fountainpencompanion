require "rails_helper"

describe ScrubReviewApproverEmails do
  let(:ink_review) { create(:ink_review) }

  def review_data(user)
    {
      title: "Great ink",
      description: "Contact me at author@example.com for questions",
      user: user
    }.to_json
  end

  def create_log(name: "ReviewApprover", transcript:)
    ink_review.agent_logs.create!(name: name, transcript: transcript)
  end

  it "replaces submitter emails in the user field of modern transcripts" do
    log =
      create_log(
        transcript: [
          { "role" => "system", "content" => "directive" },
          {
            "role" => "user",
            "content" => "The review data is: #{review_data("jane@example.com")}"
          },
          {
            "role" => "user",
            "content" => "Here are some examples: [#{review_data("bob@example.org")}]"
          }
        ]
      )

    expect(described_class.new.perform).to eq(1)

    transcript = log.reload.transcript
    expect(transcript.to_json).not_to include("jane@example.com")
    expect(transcript.to_json).not_to include("bob@example.org")
    expect(transcript[1]["content"]).to eq("The review data is: #{review_data("user")}")
    expect(transcript[2]["content"]).to eq("Here are some examples: [#{review_data("user")}]")
  end

  it "replaces submitter emails in legacy transcripts keyed by role" do
    log =
      create_log(
        transcript: [
          { "system" => "directive" },
          { "user" => "The review data is: #{review_data("jane@example.com")}" }
        ]
      )

    described_class.new.perform

    expect(log.reload.transcript[1]["user"]).to eq("The review data is: #{review_data("user")}")
  end

  it "leaves emails outside the user field untouched" do
    log = create_log(transcript: [{ "role" => "user", "content" => review_data("user") }])

    expect(described_class.new.perform).to eq(0)
    expect(log.reload.transcript[0]["content"]).to include("author@example.com")
  end

  it "leaves user fields that hold names or System untouched" do
    log =
      create_log(
        transcript: [
          { "role" => "user", "content" => review_data("Jane Doe") },
          { "role" => "user", "content" => review_data("System") }
        ]
      )

    expect(described_class.new.perform).to eq(0)
    expect(log.reload.transcript[0]["content"]).to include('"user":"Jane Doe"')
  end

  it "ignores logs of other agents" do
    log =
      create_log(
        name: "WebPageSummarizer",
        transcript: [{ "role" => "user", "content" => review_data("jane@example.com") }]
      )

    expect(described_class.new.perform).to eq(0)
    expect(log.reload.transcript[0]["content"]).to include("jane@example.com")
  end

  it "does not touch updated_at" do
    log =
      create_log(transcript: [{ "role" => "user", "content" => review_data("jane@example.com") }])
    log.update_column(:updated_at, 1.day.ago)
    original = log.reload.updated_at

    described_class.new.perform

    expect(log.reload.updated_at).to eq(original)
  end
end
