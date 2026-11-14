require "rails_helper"

describe ChangeReviewFeedState do
  let(:failure_fields) do
    { failure_count: 4, first_failed_at: 5.days.ago, last_error: "SSL error" }
  end

  def change_state(feed, enabled:)
    described_class.new(feed, enabled:).perform
  end

  describe "ignoring" do
    ReviewFeed::STATES.each do |state|
      it "ignores a #{state} feed and keeps its feed URL" do
        feed_url = "https://example.com/#{state}" unless %w[no_feed duplicate].include?(state)
        feed = create(:review_feed, state:, feed_url:)

        expect(change_state(feed, enabled: false)).to be true
        expect(feed.reload).to have_attributes(state: "ignored", feed_url:)
      end
    end
  end

  describe "re-enabling" do
    it "activates an ignored feed with a feed URL and skips what it published meanwhile" do
      feed =
        create(
          :review_feed,
          state: "ignored",
          feed_url: "https://example.com/feed",
          back_catalog_imported: true,
          **failure_fields
        )

      expect(change_state(feed, enabled: true)).to be true
      expect(feed.reload).to have_attributes(
        state: "active",
        feed_url: "https://example.com/feed",
        back_catalog_imported: false,
        failure_count: 0,
        first_failed_at: nil,
        last_error: nil
      )
    end

    it "activates a failing feed and keeps its back catalog so it catches up" do
      feed = create(:review_feed, state: "failing", back_catalog_imported: true, **failure_fields)

      expect(change_state(feed, enabled: true)).to be true
      expect(feed.reload).to have_attributes(
        state: "active",
        back_catalog_imported: true,
        failure_count: 0,
        first_failed_at: nil,
        last_error: nil
      )
    end

    %w[ignored duplicate no_feed].each do |state|
      it "queues a #{state} feed without a feed URL for discovery" do
        feed =
          create(
            :review_feed,
            state:,
            feed_url: nil,
            discovered_at: 1.day.ago,
            last_error: "Feed already used by other.example.com"
          )

        expect(change_state(feed, enabled: true)).to be true
        expect(feed.reload).to have_attributes(
          state: "no_feed",
          discovered_at: nil,
          last_error: nil
        )
        expect(feed).to be_due_for_rediscovery
      end
    end

    it "lets the next discovery run pick up a re-enabled feed without a feed URL" do
      feed = create(:review_feed, state: "ignored", feed_url: nil, discovered_at: 1.day.ago)
      expect(ReviewFeed.due_for_rediscovery).not_to include(feed)

      change_state(feed, enabled: true)

      expect { DiscoverReviewFeeds.new.perform }.to change(DiscoverReviewFeed.jobs, :size).by(1)
      expect(DiscoverReviewFeed.jobs.last["args"]).to eq([feed.host])
    end

    it "leaves an active feed as it is" do
      empty_since = 10.days.ago.round
      feed = create(:review_feed, back_catalog_imported: true, empty_since:)

      expect(change_state(feed, enabled: true)).to be true
      expect(feed.reload).to have_attributes(
        state: "active",
        back_catalog_imported: true,
        empty_since:
      )
    end

    [
      { state: "ignored" },
      { state: "failing" },
      { state: "duplicate", feed_url: nil },
      { state: "no_feed", feed_url: nil }
    ].each do |attributes|
      url = attributes.key?(:feed_url) ? "without" : "with"
      it "starts a new empty streak for a #{attributes[:state]} feed #{url} a feed URL" do
        feed = create(:review_feed, **attributes, empty_since: 10.days.ago)

        expect(change_state(feed, enabled: true)).to be true
        expect(feed.reload.empty_since).to be_nil
      end
    end
  end
end
