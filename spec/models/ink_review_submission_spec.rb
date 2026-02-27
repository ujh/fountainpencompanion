require "rails_helper"

describe InkReviewSubmission do
  it "fails validation if the url is missing" do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:url)
  end

  it "fails validation if the user association is missing" do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:user)
  end

  it "fails validation if the macro cluster association is missing" do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:macro_cluster)
  end

  it "fails if user has submitted url to cluster already" do
    existing_submission = create(:ink_review_submission)
    submission =
      described_class.new(
        url: existing_submission.url,
        user: existing_submission.user,
        macro_cluster: existing_submission.macro_cluster
      )
    expect(submission).not_to be_valid
    expect(submission.errors).to include(:url)
  end

  it "does not fail if user has submitted url to other cluster" do
    existing_submission = create(:ink_review_submission)
    submission =
      described_class.new(
        url: existing_submission.url,
        user: existing_submission.user,
        macro_cluster: create(:macro_cluster)
      )
    expect(submission).to be_valid
  end

  it "does not fail if other user has submitted url to cluster" do
    existing_submission = create(:ink_review_submission)
    submission =
      described_class.new(
        url: existing_submission.url,
        user: create(:user),
        macro_cluster: existing_submission.macro_cluster
      )
    expect(submission).to be_valid
  end

  describe "Instagram URL validation" do
    %w[
      https://instagram.com/p/abc123
      https://www.instagram.com/p/abc123
      https://m.instagram.com/p/abc123
      http://instagram.com/reel/abc123
      https://INSTAGRAM.COM/p/abc123
    ].each do |instagram_url|
      it "rejects #{instagram_url}" do
        submission = build(:ink_review_submission, url: instagram_url)
        expect(submission).not_to be_valid
        expect(submission.errors[:url].first).to include("Instagram URLs are not supported")
      end
    end

    %w[
      https://example.com/review
      https://youtube.com/watch?v=abc
      https://notinstagram.com/p/abc
    ].each do |valid_url|
      it "allows #{valid_url}" do
        submission = build(:ink_review_submission, url: valid_url)
        expect(submission).to be_valid
      end
    end
  end
end
