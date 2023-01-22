require "rails_helper"

describe InkReview do
  it "fails validation if the title is missing" do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:title)
  end

  it "fails validation if the url is missing" do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:url)
  end

  it "fails validation if the image is missing" do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:image)
  end

  it "fails validation if the macro cluster association is missing" do
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:macro_cluster)
  end

  it "fails validation if it is not a valid url" do
    subject.url = "weeeeeeee"
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:url)
  end

  it "fails validation if url is a blank string" do
    subject.url = "          "
    expect(subject).not_to be_valid
    expect(subject.errors).to include(:url)
  end

  it "sets host automatically from the url" do
    subject.url = "https://example.com/some/page"
    expect(subject.host).to eq("example.com")
  end
end
