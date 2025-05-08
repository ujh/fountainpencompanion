require "rails_helper"

describe FetchReviews::MountainOfInk do
  before do
    stub_request(:get, "https://mountainofink.com/?format=rss").to_return(
      body: file_fixture("mountainofink.rss")
    )
  end

  it "adds all items as ink reviews" do
    expect do FetchReviews::MountainOfInk.new.perform end.to change(
      FetchReviews::ProcessWebPageForReview.jobs,
      :count
    ).by(20)
  end
end
