require "rails_helper"

describe UpdateReviewFeed do
  def update(feed, params)
    described_class.new(feed, params).perform
  end

  it "toggles curated without touching the back catalog flag" do
    feed = create(:review_feed, :curated)

    expect(update(feed, { curated: "0", feed_url: feed.feed_url })).to be true
    expect(feed.reload.curated).to be false
    expect(feed.back_catalog_imported).to be true
  end

  it "ignores whitespace around an unchanged feed URL" do
    feed = create(:review_feed, :curated, feed_url: "https://example.com/feed")

    update(feed, { feed_url: "  https://example.com/feed  " })

    expect(feed.reload.back_catalog_imported).to be true
  end

  it "skips the new feed's back catalog when the feed URL changes" do
    feed = create(:review_feed, :curated, feed_url: "https://example.com/feed")

    expect(update(feed, { feed_url: "https://example.com/atom.xml" })).to be true
    expect(feed.reload).to have_attributes(
      feed_url: "https://example.com/atom.xml",
      back_catalog_imported: false,
      state: "active"
    )
  end

  it "keeps a failing feed failing when its feed URL changes" do
    feed =
      create(
        :review_feed,
        :curated,
        state: "failing",
        failure_count: 7,
        first_failed_at: 4.days.ago,
        last_error: "timeout"
      )

    update(feed, { feed_url: "https://example.com/new-feed" })

    expect(feed.reload).to have_attributes(
      state: "failing",
      failure_count: 7,
      last_error: "timeout",
      back_catalog_imported: false
    )
  end

  %w[no_feed ignored duplicate].each do |state|
    it "activates a #{state} feed that gets a feed URL" do
      feed =
        create(
          :review_feed,
          state: state,
          feed_url: nil,
          back_catalog_imported: true,
          failure_count: 2,
          first_failed_at: 1.day.ago,
          last_error: "Feed already used by other.example.com"
        )

      expect(update(feed, { feed_url: "https://example.com/feed" })).to be true
      expect(feed.reload).to have_attributes(
        state: "active",
        feed_url: "https://example.com/feed",
        back_catalog_imported: false,
        failure_count: 0,
        first_failed_at: nil,
        last_error: nil
      )
    end

    it "leaves a #{state} feed without a feed URL alone when the URL stays blank" do
      feed = create(:review_feed, state: state, feed_url: nil, back_catalog_imported: true)

      expect(update(feed, { feed_url: "", curated: "1" })).to be true
      expect(feed.reload).to have_attributes(
        state: state,
        feed_url: nil,
        curated: true,
        back_catalog_imported: true
      )
    end
  end

  it "keeps an ignored feed ignored when its feed URL is removed" do
    feed = create(:review_feed, state: "ignored", feed_url: "https://example.com/feed")

    expect(update(feed, { feed_url: "" })).to be true
    expect(feed.reload).to have_attributes(state: "ignored", feed_url: nil)
  end

  %w[active failing].each do |state|
    it "refuses to blank the feed URL of a #{state} feed" do
      feed = create(:review_feed, state: state, feed_url: "https://example.com/feed")

      expect(update(feed, { feed_url: " " })).to be false
      expect(feed.errors[:feed_url]).to include("can't be blank")
      expect(feed.reload.feed_url).to eq("https://example.com/feed")
    end
  end

  it "refuses a feed URL another feed already uses" do
    create(:review_feed, feed_url: "https://example.com/feed")
    feed = create(:review_feed, :ignored)

    expect(update(feed, { feed_url: "https://example.com/feed" })).to be false
    expect(feed.errors[:feed_url]).to include("has already been taken")
    expect(feed.reload).to have_attributes(state: "ignored", feed_url: nil)
  end
end
