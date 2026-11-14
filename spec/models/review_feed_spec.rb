require "rails_helper"
require "active_record/testing/query_assertions"

describe ReviewFeed do
  describe ".normalize_host" do
    it "returns the host of a URL" do
      expect(described_class.normalize_host("https://example.com/2024/01/review/")).to eq(
        "example.com"
      )
    end

    it "accepts a bare host" do
      expect(described_class.normalize_host("blog.example.com")).to eq("blog.example.com")
    end

    it "lowercases" do
      expect(described_class.normalize_host("https://Blog.Example.COM/post")).to eq(
        "blog.example.com"
      )
    end

    it "strips a leading www. from a URL" do
      expect(described_class.normalize_host("https://www.example.com/feed/")).to eq("example.com")
    end

    it "strips a leading www. from a host" do
      expect(described_class.normalize_host("WWW.example.com")).to eq("example.com")
    end

    it "strips only one leading www." do
      expect(described_class.normalize_host("www.www.example.com")).to eq("www.example.com")
    end

    it "keeps other subdomains" do
      expect(described_class.normalize_host("https://inksharks.blogspot.com/feeds")).to eq(
        "inksharks.blogspot.com"
      )
    end

    it "ignores the port, path and query" do
      expect(described_class.normalize_host("http://www.example.com:8080/a?b=c")).to eq(
        "example.com"
      )
    end

    it "ignores surrounding whitespace" do
      expect(described_class.normalize_host("  example.com \n")).to eq("example.com")
    end

    it "accepts a URL with non-ASCII characters in the path" do
      expect(described_class.normalize_host("https://example.com/tinte-grün/")).to eq("example.com")
    end

    it "accepts a URL with a space in the path" do
      expect(described_class.normalize_host("https://example.com/a b")).to eq("example.com")
    end

    it "accepts a URL with a pipe in the query" do
      expect(described_class.normalize_host("https://www.example.com/search?q=a|b")).to eq(
        "example.com"
      )
    end

    it "returns nil for nil" do
      expect(described_class.normalize_host(nil)).to be_nil
    end

    it "returns nil for blank input" do
      expect(described_class.normalize_host("  ")).to be_nil
    end

    it "returns nil for a URL without a host" do
      expect(described_class.normalize_host("https://")).to be_nil
    end

    it "returns nil for text that is not a host" do
      expect(described_class.normalize_host("not a host")).to be_nil
    end

    it "returns nil for garbage" do
      expect(described_class.normalize_host("%%%")).to be_nil
      expect(described_class.normalize_host("ht!tp://example.com")).to be_nil
    end

    it "returns nil for a bare www." do
      expect(described_class.normalize_host("www.")).to be_nil
    end
  end

  describe "host normalisation" do
    it "normalises the host before saving" do
      feed = create(:review_feed, host: "https://WWW.Example.com/blog/")

      expect(feed.reload.host).to eq("example.com")
    end

    it "reports a host that cannot be normalised as invalid" do
      feed = build(:review_feed, host: "not a host")

      expect(feed).not_to be_valid
      expect(feed.errors[:host]).to eq(["is invalid"])
    end

    it "reports a blank host as blank" do
      feed = build(:review_feed, host: "  ")

      expect(feed).not_to be_valid
      expect(feed.errors[:host]).to eq(["can't be blank"])
    end
  end

  describe "validations" do
    it "is valid when built from the factory" do
      expect(build(:review_feed)).to be_valid
    end

    it "saves every state in STATES" do
      described_class::STATES.each do |state|
        feed = create(:review_feed, state: state)

        expect(feed.reload.state).to eq(state)
      end
    end

    it "rejects an unknown state" do
      feed = build(:review_feed, state: "paused")

      expect(feed).not_to be_valid
      expect(feed.errors[:state]).to be_present
    end

    it "rejects a host that is already taken once normalised" do
      create(:review_feed, host: "example.com")
      feed = build(:review_feed, host: "https://www.Example.com/")

      expect(feed).not_to be_valid
      expect(feed.errors[:host]).to include("has already been taken")
    end

    it "rejects a feed URL that is already taken" do
      create(:review_feed, feed_url: "https://feeds.example.com/blog")
      feed = build(:review_feed, feed_url: "https://feeds.example.com/blog")

      expect(feed).not_to be_valid
      expect(feed.errors[:feed_url]).to include("has already been taken")
    end

    it "allows several feeds without a feed URL" do
      create(:review_feed, :no_feed)
      feed = build(:review_feed, :ignored)

      expect(feed).to be_valid
    end

    it "stores a blank feed URL as nil" do
      feed = create(:review_feed, :no_feed, feed_url: "  ")

      expect(feed.reload.feed_url).to be_nil
    end

    %w[active failing].each do |state|
      it "requires a feed URL when #{state}" do
        feed = build(:review_feed, state: state, feed_url: nil)

        expect(feed).not_to be_valid
        expect(feed.errors[:feed_url]).to include("can't be blank")
      end
    end

    %w[no_feed ignored duplicate].each do |state|
      it "does not require a feed URL when #{state}" do
        expect(build(:review_feed, state: state, feed_url: nil)).to be_valid
      end
    end
  end

  describe "database constraints" do
    it "rejects an active feed without a feed URL" do
      feed = create(:review_feed, :no_feed)

      expect { feed.update_column(:state, "active") }.to raise_error(
        ActiveRecord::StatementInvalid,
        /review_feeds_fetchable_feed_url/
      )
    end

    it "rejects removing the feed URL of a failing feed" do
      feed = create(:review_feed, state: "failing")

      expect { feed.update_column(:feed_url, nil) }.to raise_error(
        ActiveRecord::StatementInvalid,
        /review_feeds_fetchable_feed_url/
      )
    end

    it "rejects an unknown state" do
      feed = create(:review_feed)

      expect { feed.update_column(:state, "paused") }.to raise_error(
        ActiveRecord::StatementInvalid,
        /review_feeds_state_values/
      )
    end
  end

  describe ".fetchable" do
    it "returns active and failing feeds" do
      active = create(:review_feed, state: "active")
      failing = create(:review_feed, state: "failing")

      expect(described_class.fetchable).to contain_exactly(active, failing)
    end

    it "excludes feeds in other states" do
      create(:review_feed, :no_feed)
      create(:review_feed, :ignored)
      create(:review_feed, state: "duplicate", feed_url: nil)

      expect(described_class.fetchable).to be_empty
    end
  end

  describe ".denylisted?" do
    it "is true for a denylisted host" do
      expect(described_class.denylisted?("youtube.com")).to be(true)
    end

    it "is true for a subdomain of a denylisted host" do
      expect(described_class.denylisted?("m.youtube.com")).to be(true)
      expect(described_class.denylisted?("en.wikipedia.org")).to be(true)
    end

    it "normalises the host" do
      expect(described_class.denylisted?("WWW.YouTube.com")).to be(true)
    end

    it "accepts a URL" do
      expect(
        described_class.denylisted?("https://www.youtube.com/feeds/videos.xml?channel_id=x")
      ).to(be(true))
    end

    it "is false for a host that only ends with a denylisted name" do
      expect(described_class.denylisted?("notyoutube.com")).to be(false)
    end

    it "is false for other hosts" do
      expect(described_class.denylisted?("mountainofink.com")).to be(false)
    end

    it "is false for a blank host" do
      expect(described_class.denylisted?(nil)).to be(false)
    end

    it "covers every platform on the list" do
      expect(described_class::DENYLIST).to contain_exactly(
        "youtube.com",
        "youtu.be",
        "instagram.com",
        "reddit.com",
        "wikipedia.org",
        "fountainpennetwork.com",
        "facebook.com",
        "medium.com",
        "pinterest.com",
        "flickr.com",
        "fountainpennetwork.net",
        "badgerandblade.com",
        "ko-fi.com",
        "write.as"
      )
    end
  end

  describe ".qualifying_hosts" do
    include RSpec::Rails::MinitestAssertionAdapter
    include ActiveSupport::Testing::Assertions
    include ActiveRecord::Assertions::QueryAssertions

    def approved_reviews(host, count, created_at: 1.month.ago, **attributes)
      create_list(
        :ink_review,
        count,
        approved_at: Time.current,
        created_at:,
        **attributes
      ) { |r, i| r.update!(url: "https://#{host}/review-#{i}-#{SecureRandom.hex(4)}") }
    end

    it "returns hosts with at least three approved reviews" do
      approved_reviews("three.test", 3)
      approved_reviews("two.test", 2)

      expect(described_class.qualifying_hosts).to eq(["three.test"])
    end

    it "requires one of the reviews to be less than two years old" do
      approved_reviews("recent.test", 2, created_at: 3.years.ago)
      approved_reviews("recent.test", 1, created_at: 23.months.ago)
      approved_reviews("old.test", 3, created_at: 25.months.ago)

      expect(described_class.qualifying_hosts).to eq(["recent.test"])
    end

    it "does not count unapproved reviews" do
      approved_reviews("blog.test", 2)
      create(:ink_review, url: "https://blog.test/queued")
      create(:ink_review, url: "https://blog.test/rejected", rejected_at: Time.current)

      expect(described_class.qualifying_hosts).to be_empty
    end

    it "does not count YouTube reviews" do
      channel = create(:you_tube_channel)
      approved_reviews("video.test", 3, you_tube_channel: channel)
      approved_reviews("mixed.test", 2)
      approved_reviews("mixed.test", 1, you_tube_channel: channel)

      expect(described_class.qualifying_hosts).to be_empty
    end

    it "groups hosts by their normalised form" do
      approved_reviews("www.blog.test", 1)
      approved_reviews("Blog.test", 1)
      approved_reviews("WWW.BLOG.TEST", 1)

      expect(described_class.qualifying_hosts).to eq(["blog.test"])
    end

    it "keeps subdomains apart" do
      approved_reviews("a.blog.test", 2)
      approved_reviews("b.blog.test", 1)

      expect(described_class.qualifying_hosts).to be_empty
    end

    it "excludes hosts that already have a feed in any state" do
      approved_reviews("www.active.test", 3)
      approved_reviews("ignored.test", 3)
      approved_reviews("no-feed.test", 3)
      approved_reviews("new.test", 3)
      create(:review_feed, host: "active.test")
      create(:review_feed, :ignored, host: "ignored.test")
      create(:review_feed, :no_feed, host: "no-feed.test")

      expect(described_class.qualifying_hosts).to eq(["new.test"])
    end

    it "excludes denylisted hosts and their subdomains" do
      approved_reviews("www.youtube.com", 3)
      approved_reviews("en.wikipedia.org", 3)
      approved_reviews("blog.test", 3)

      expect(described_class.qualifying_hosts).to eq(["blog.test"])
    end

    it "ignores reviews without a host" do
      approved_reviews("blog.test", 3).each { |review| review.update_columns(host: nil) }

      expect(described_class.qualifying_hosts).to be_empty
    end

    it "runs a single query" do
      approved_reviews("a.test", 3)
      approved_reviews("b.test", 3)
      approved_reviews("www.youtube.com", 3)
      create(:review_feed, host: "b.test")

      hosts = nil
      assert_queries_match(/SELECT/, count: 1) { hosts = described_class.qualifying_hosts }
      expect(hosts).to eq(["a.test"])
    end
  end

  describe "#due_for_rediscovery?" do
    it "is true for a no_feed row that was never discovered" do
      expect(build(:review_feed, :no_feed, discovered_at: nil)).to be_due_for_rediscovery
    end

    it "is true for a no_feed row discovered more than 30 days ago" do
      expect(build(:review_feed, :no_feed, discovered_at: 31.days.ago)).to be_due_for_rediscovery
    end

    it "is false for a no_feed row discovered recently" do
      expect(build(:review_feed, :no_feed, discovered_at: 29.days.ago)).not_to(
        be_due_for_rediscovery
      )
    end

    it "is false for rows in other states" do
      expect(build(:review_feed, discovered_at: nil)).not_to be_due_for_rediscovery
      expect(build(:review_feed, :ignored, discovered_at: nil)).not_to be_due_for_rediscovery
    end
  end

  describe ".due_for_rediscovery" do
    it "returns no_feed rows that were never discovered" do
      feed = create(:review_feed, :no_feed, discovered_at: nil)

      expect(described_class.due_for_rediscovery).to eq([feed])
    end

    it "returns no_feed rows discovered more than 30 days ago" do
      feed = create(:review_feed, :no_feed, discovered_at: 31.days.ago)

      expect(described_class.due_for_rediscovery).to eq([feed])
    end

    it "skips no_feed rows discovered recently" do
      create(:review_feed, :no_feed, discovered_at: 29.days.ago)

      expect(described_class.due_for_rediscovery).to be_empty
    end

    it "skips rows in other states" do
      create(:review_feed, discovered_at: nil)
      create(:review_feed, :ignored, discovered_at: nil)
      create(:review_feed, state: "duplicate", feed_url: nil, discovered_at: nil)

      expect(described_class.due_for_rediscovery).to be_empty
    end
  end

  describe "#due?" do
    def due_hours(feed)
      (0..23).select { |hour| feed.due?(hour) }
    end

    it "is due every hour for a curated active feed" do
      expect(due_hours(create(:review_feed, :curated))).to eq((0..23).to_a)
    end

    it "is due every hour for a curated failing feed" do
      expect(due_hours(create(:review_feed, :curated, state: "failing"))).to eq((0..23).to_a)
    end

    it "is due every fourth hour for a non-curated active feed, spread by id" do
      feed = create(:review_feed)

      expect(due_hours(feed)).to eq((0..23).select { |hour| hour % 4 == feed.id % 4 })
    end

    it "is due once a day for a non-curated failing feed, spread by id" do
      feed = create(:review_feed, state: "failing")

      expect(due_hours(feed)).to eq([feed.id % 24])
    end
  end

  describe "#web_page_for_reviews" do
    it "returns the pages found through the feed" do
      feed = create(:review_feed)
      page = create(:web_page_for_review, review_feed: feed)
      create(:web_page_for_review)

      expect(feed.web_page_for_reviews).to contain_exactly(page)
    end

    it "unlinks the pages when the feed is destroyed" do
      feed = create(:review_feed)
      page = create(:web_page_for_review, review_feed: feed)

      feed.destroy!

      expect(page.reload.review_feed).to be_nil
    end
  end
end
