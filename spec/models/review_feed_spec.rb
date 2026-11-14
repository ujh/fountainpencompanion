require "rails_helper"

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

    it "is invalid when the host cannot be normalised" do
      feed = build(:review_feed, host: "not a host")

      expect(feed).not_to be_valid
      expect(feed.errors[:host]).to be_present
    end
  end

  describe "validations" do
    it "is valid when built from the factory" do
      expect(build(:review_feed)).to be_valid
    end

    it "accepts every state in STATES" do
      described_class::STATES.each do |state|
        feed = build(:review_feed, state: state)

        expect(feed).to be_valid, "expected #{state} to be valid"
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
