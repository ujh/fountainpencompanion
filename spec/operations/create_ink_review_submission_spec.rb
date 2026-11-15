require "rails_helper"

describe CreateInkReviewSubmission do
  let(:user) { create(:user) }
  let(:macro_cluster) { create(:macro_cluster) }
  let(:url) { "http://example.com" }
  let(:automatic) { false }

  subject do
    described_class.new(user: user, macro_cluster: macro_cluster, url: url, automatic: automatic)
  end

  it "saves the submission" do
    expect do subject.perform end.to change(InkReviewSubmission, :count).by(1)
  end

  it "sets the correct attributes" do
    submission = subject.perform
    expect(submission.user).to eq(user)
    expect(submission.macro_cluster).to eq(macro_cluster)
    expect(submission.url).to eq("http://example.com")
  end

  it "schedules the processing job" do
    expect do subject.perform end.to change(ProcessInkReviewSubmission.jobs, :count).by(1)
  end

  it "passes the submission id to the processing job" do
    submission = subject.perform
    job = ProcessInkReviewSubmission.jobs.first
    expect(job["args"]).to eq([submission.id])
  end

  it "does not schedule the processing job if the submission cannot be saved" do
    expect do
      described_class.new(user: nil, macro_cluster: nil, url: nil).perform
    end.not_to change(ProcessInkReviewSubmission.jobs, :count)
  end

  context "when the submission already exists" do
    let!(:existing) do
      create(:ink_review_submission, user: user, macro_cluster: macro_cluster, url: url)
    end

    it "returns the existing submission" do
      expect(subject.perform).to eq(existing)
    end

    it "schedules the processing job again while it is not linked to a review" do
      expect do subject.perform end.to change(ProcessInkReviewSubmission.jobs, :count).by(1)
    end

    it "does not schedule the processing job once it is linked to a review" do
      existing.update!(ink_review: create(:ink_review, macro_cluster: macro_cluster))

      expect do subject.perform end.not_to change(ProcessInkReviewSubmission.jobs, :count)
    end
  end

  context "daily limit" do
    def create_recent_submissions(count, created_at: 1.hour.ago)
      count.times do |i|
        create(:ink_review_submission, user: user, url: "http://example.com/#{i}", created_at:)
      end
    end

    it "accepts the submission just below the limit" do
      create_recent_submissions(described_class::DAILY_LIMIT - 1)

      expect(subject.perform).to be_persisted
    end

    context "when the limit is reached" do
      before { create_recent_submissions(described_class::DAILY_LIMIT) }

      it "does not save the submission" do
        expect do subject.perform end.not_to change(InkReviewSubmission, :count)
      end

      it "returns the submission with an error" do
        expect(subject.perform.errors.full_messages).to eq(
          ["You've reached the daily limit of review submissions, please try again tomorrow"]
        )
      end

      it "does not schedule the processing job" do
        expect do subject.perform end.not_to change(ProcessInkReviewSubmission.jobs, :count)
      end

      it "still returns an existing submission for the same url" do
        existing = InkReviewSubmission.where(user:).first
        submission =
          described_class.new(
            user:,
            macro_cluster: existing.macro_cluster,
            url: existing.url
          ).perform

        expect(submission).to eq(existing)
      end

      it "does not count submissions by other users" do
        submission =
          described_class.new(user: create(:user), macro_cluster: macro_cluster, url: url).perform

        expect(submission).to be_persisted
      end
    end

    it "does not count submissions older than 24 hours" do
      create_recent_submissions(described_class::DAILY_LIMIT, created_at: 25.hours.ago)

      expect(subject.perform).to be_persisted
    end

    it "does not apply to automatic submissions" do
      create_recent_submissions(described_class::DAILY_LIMIT)

      submission = described_class.new(user:, macro_cluster:, url:, automatic: true).perform

      expect(submission).to be_persisted
    end
  end

  context "automatic review" do
    let(:automatic) { true }

    it "saves the submission" do
      expect do subject.perform end.to change(InkReviewSubmission, :count).by(1)
    end

    it "schedules the processing job" do
      expect do subject.perform end.to change(ProcessInkReviewSubmission.jobs, :count).by(1)
    end

    it "does not schedule the processing job if the submission already exists" do
      submission = create(:ink_review_submission)
      expect do
        described_class.new(
          user: submission.user,
          macro_cluster: submission.macro_cluster,
          url: submission.url,
          automatic: true
        ).perform
      end.not_to change(ProcessInkReviewSubmission.jobs, :count)
    end
  end
end
