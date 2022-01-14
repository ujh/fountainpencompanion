require 'rails_helper'

describe InkReviewSubmission do
  it 'fails validation if the url is missing' do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:url)
  end

  it 'fails validation if the user association is missing' do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:user)
  end

  it 'fails validation if the macro cluster association is missing' do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:macro_cluster)
  end

  it 'fails if user has submitted url to cluster already' do
    existing_submission = create(:ink_review_submission)
    submission = described_class.new(
      url: existing_submission.url,
      user: existing_submission.user,
      macro_cluster: existing_submission.macro_cluster
    )
    expect(submission).not_to be_valid
    expect(submission.errors).to include(:url)
  end

  it 'does not fail if user has submitted url to other cluster' do
    existing_submission = create(:ink_review_submission)
    submission = described_class.new(
      url: existing_submission.url,
      user: existing_submission.user,
      macro_cluster: create(:macro_cluster)
    )
    expect(submission).to be_valid
  end

  it 'does not fail if other user has submitted url to cluster' do
    existing_submission = create(:ink_review_submission)
    submission = described_class.new(
      url: existing_submission.url,
      user: create(:user),
      macro_cluster: existing_submission.macro_cluster
    )
    expect(submission).to be_valid
  end
end
