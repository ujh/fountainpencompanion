require "rails_helper"

describe DiscoverReviewFeedForHost do
  include ActiveSupport::Testing::TimeHelpers

  let(:feed_url) { "https://blog.test/feed/" }
  let(:discover_feed) { instance_double(DiscoverFeed, perform: feed_url) }

  before { allow(DiscoverFeed).to receive(:new).and_return(discover_feed) }

  def approved_review(url, created_at: 1.day.ago)
    create(:ink_review, url:, approved_at: Time.current, created_at:)
  end

  def discover(host = "blog.test")
    described_class.new(host).perform
  end

  it "creates an active, non-curated feed whose back catalog still has to be skipped" do
    freeze_time do
      expect(discover).to be(true)

      expect(ReviewFeed.sole).to have_attributes(
        host: "blog.test",
        feed_url:,
        state: "active",
        curated: false,
        back_catalog_imported: false,
        last_error: nil,
        discovered_at: Time.current
      )
    end
  end

  it "normalises the host" do
    discover("WWW.Blog.test")

    expect(ReviewFeed.sole.host).to eq("blog.test")
    expect(DiscoverFeed).to have_received(:new).with(host: "blog.test", sample_urls: [])
  end

  it "samples the three most recent approved reviews of the host, with or without www." do
    approved_review("https://blog.test/oldest", created_at: 4.days.ago)
    approved_review("https://www.blog.test/third", created_at: 3.days.ago)
    approved_review("https://Blog.test/second", created_at: 2.days.ago)
    approved_review("https://WWW.blog.test/newest", created_at: 1.day.ago)
    create(:ink_review, url: "https://blog.test/queued", created_at: 1.hour.ago)
    approved_review("https://other.blog.test/elsewhere", created_at: 1.hour.ago)

    discover

    expect(DiscoverFeed).to have_received(:new).with(
      host: "blog.test",
      sample_urls: %w[
        https://WWW.blog.test/newest
        https://Blog.test/second
        https://www.blog.test/third
      ]
    )
  end

  it "records a host without a feed as no_feed" do
    allow(discover_feed).to receive(:perform).and_return(nil)

    freeze_time do
      expect(discover).to be(true)

      expect(ReviewFeed.sole).to have_attributes(
        host: "blog.test",
        feed_url: nil,
        state: "no_feed",
        last_error: nil,
        discovered_at: Time.current
      )
    end
  end

  it "records a feed that another host already uses as a duplicate" do
    create(:review_feed, host: "old-name.test", feed_url:)

    discover

    expect(ReviewFeed.find_by(host: "blog.test")).to have_attributes(
      state: "duplicate",
      feed_url: nil,
      last_error: "Feed #{feed_url} belongs to old-name.test"
    )
  end

  it "rejects a feed on a denylisted host" do
    allow(discover_feed).to receive(:perform).and_return(
      "https://www.youtube.com/feeds/videos.xml?channel_id=UC1"
    )

    discover

    expect(ReviewFeed.sole).to have_attributes(
      state: "no_feed",
      feed_url: nil,
      last_error:
        "Feed https://www.youtube.com/feeds/videos.xml?channel_id=UC1 is on a denylisted host"
    )
  end

  it "rejects the YouTube feed of a blog that redirects to its YouTube channel" do
    allow(DiscoverFeed).to receive(:new).and_call_original
    approved_review("https://blog.test/review")
    channel = "https://www.youtube.com/@blog"
    videos = "https://www.youtube.com/feeds/videos.xml?channel_id=UC1"
    %w[https://blog.test/review https://blog.test/].each do |url|
      stub_request(:get, url).to_return(status: 301, headers: { "Location" => channel })
    end
    stub_request(:get, channel).to_return(
      status: 200,
      body:
        %(<html><head><link rel="alternate" type="application/rss+xml" href="#{videos}"></head></html>)
    )
    stub_request(:get, videos).to_return(status: 200, body: <<~XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom"><title>Blog</title><id>yt:channel:UC1</id>
        <updated>2026-11-01T00:00:00Z</updated>
        <entry><title>Ink</title><id>yt:video:1</id><updated>2026-11-01T00:00:00Z</updated>
          <link rel="alternate" href="https://www.youtube.com/watch?v=1"/></entry>
      </feed>
    XML

    discover

    expect(ReviewFeed.sole).to have_attributes(
      host: "blog.test",
      state: "no_feed",
      feed_url: nil,
      last_error: "Feed #{videos} is on a denylisted host"
    )
  end

  describe "existing rows" do
    it "turns a no_feed row active when a feed is found" do
      review_feed =
        create(
          :review_feed,
          :no_feed,
          host: "blog.test",
          discovered_at: 40.days.ago,
          last_error: "x"
        )

      freeze_time do
        expect(discover).to be(true)

        expect(review_feed.reload).to have_attributes(
          state: "active",
          feed_url:,
          curated: false,
          back_catalog_imported: false,
          last_error: nil,
          discovered_at: Time.current
        )
      end
    end

    it "keeps the curated flag of a no_feed row it turns active" do
      review_feed =
        create(:review_feed, :no_feed, host: "blog.test", curated: true, discovered_at: nil)

      discover

      expect(review_feed.reload).to have_attributes(state: "active", feed_url:, curated: true)
    end

    it "leaves a no_feed row alone that was discovered recently" do
      review_feed = create(:review_feed, :no_feed, host: "blog.test", discovered_at: 29.days.ago)

      expect(discover).to be(false)

      expect(DiscoverFeed).not_to have_received(:new)
      expect(review_feed.reload).to have_attributes(state: "no_feed", feed_url: nil)
    end

    it "keeps a no_feed row and records the attempt when still no feed is found" do
      allow(discover_feed).to receive(:perform).and_return(nil)
      review_feed = create(:review_feed, :no_feed, host: "blog.test", discovered_at: 40.days.ago)

      freeze_time do
        discover

        expect(review_feed.reload).to have_attributes(
          state: "no_feed",
          feed_url: nil,
          discovered_at: Time.current
        )
      end
    end

    %w[active ignored failing duplicate].each do |state|
      it "leaves a #{state} row alone without looking for a feed" do
        review_feed =
          create(
            :review_feed,
            host: "blog.test",
            state:,
            feed_url: (%w[active failing].include?(state) ? "https://blog.test/rss" : nil)
          )

        expect(discover).to be(false)

        expect(DiscoverFeed).not_to have_received(:new)
        expect(review_feed.reload).to have_attributes(state:, discovered_at: nil)
      end
    end

    it "keeps a row ignored that an admin ignored while discovery ran" do
      review_feed = create(:review_feed, :no_feed, host: "blog.test")
      allow(discover_feed).to receive(:perform) do
        review_feed.update_columns(state: "ignored")
        feed_url
      end

      expect(discover).to be(false)

      expect(review_feed.reload).to have_attributes(
        state: "ignored",
        feed_url: nil,
        discovered_at: nil
      )
    end

    it "keeps a row that was created for the host while discovery ran" do
      allow(discover_feed).to receive(:perform) do
        create(:review_feed, :ignored, host: "blog.test")
        feed_url
      end

      expect(discover).to be(false)

      expect(ReviewFeed.sole).to have_attributes(state: "ignored", feed_url: nil)
    end
  end

  it "skips the host when a concurrent insert wins the unique index" do
    allow_any_instance_of(ReviewFeed).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)

    expect(discover).to be(false)

    expect(ReviewFeed.count).to eq(0)
  end

  it "does nothing for a value that is not a host" do
    expect(discover("not a host")).to be(false)

    expect(DiscoverFeed).not_to have_received(:new)
    expect(ReviewFeed.count).to eq(0)
  end
end
