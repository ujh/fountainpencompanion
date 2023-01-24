require "rails_helper"

describe FetchReviews::PenAddict do
  before do
    stub_request(:get, "https://penaddict.com/blog?format=rss").to_return(
      body: file_fixture("penaddict.rss")
    )
  end

  it "adds all items as ink reviews" do
    expect do FetchReviews::PenAddict.new.perform end.to change(
      FetchReviews::SubmitReview.jobs,
      :count
    ).by(5)
  end
end
