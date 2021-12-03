require 'rails_helper'

describe InkReview do
  it 'fails validation if the title is missing' do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:title)
  end

  it 'fails validation if the url is missing' do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:url)
  end

  it 'fails validation if the image is missing' do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:image)
  end

  it 'fails validation if the macro cluster association is missing' do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:macro_cluster)
  end
end
