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
end
