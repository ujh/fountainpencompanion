require "rails_helper"

describe DiscoverReviewFeed do
  it "discovers the feed of the host" do
    create(:ink_review, url: "https://blog.test/review", approved_at: Time.current)
    allow(DiscoverFeed).to receive(:new).and_return(
      instance_double(DiscoverFeed, perform: "https://blog.test/feed/")
    )

    described_class.new.perform("blog.test")

    expect(ReviewFeed.sole).to have_attributes(
      host: "blog.test",
      feed_url: "https://blog.test/feed/",
      state: "active"
    )
  end

  it "uses the reviews queue" do
    expect(described_class.get_sidekiq_options["queue"]).to eq("reviews")
  end
end
