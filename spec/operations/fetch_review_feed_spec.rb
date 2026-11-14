require "rails_helper"

describe FetchReviewFeed do
  include ActiveSupport::Testing::TimeHelpers

  let(:feed_url) { "https://feed.test/rss" }
  let(:review_feed) { create(:review_feed, :curated, feed_url:) }

  before do
    allow(Resolv).to receive(:getaddresses).with("feed.test").and_return(["93.184.216.34"])
    allow(Honeybadger).to receive(:notify)
  end

  def rss(*items)
    entries =
      items
        .map do |title, url, category|
          category_tag = category && "<category>#{category}</category>"
          "<item><title>#{title}</title><link>#{url}</link>#{category_tag}</item>"
        end
        .join
    <<~XML
      <?xml version="1.0"?>
      <rss version="2.0"><channel><title>t</title><link>https://feed.test</link><description>d</description>
        #{entries}
      </channel></rss>
    XML
  end

  def stub_feed(*items)
    stub_request(:get, feed_url).to_return(status: 200, body: rss(*items))
  end

  def stub_failure
    stub_request(:get, feed_url).to_return(status: 503)
  end

  def enqueued_page_ids
    FetchReviews::ProcessWebPageForReview.jobs.map { |job| job["args"].first }
  end

  describe "items" do
    it "creates pending pages for new items and enqueues them" do
      stub_feed(
        ["Pilot Kon-peki", "https://feed.test/kon-peki"],
        ["Diamine Oxblood", "https://feed.test/oxblood"]
      )

      expect(described_class.new(review_feed).perform).to be(true)

      pages = WebPageForReview.order(:id)
      expect(pages.map { |page| [page.url, page.state, page.data["search_term"]] }).to eq(
        [
          ["https://feed.test/kon-peki", "pending", "Pilot Kon-peki"],
          ["https://feed.test/oxblood", "pending", "Diamine Oxblood"]
        ]
      )
      expect(pages.map(&:review_feed)).to eq([review_feed, review_feed])
      expect(enqueued_page_ids).to eq(pages.map(&:id))
    end

    it "creates one page for an item listed twice" do
      stub_feed(%w[Twice https://feed.test/twice], %w[Again https://feed.test/twice])

      described_class.new(review_feed).perform

      expect(WebPageForReview.pluck(:url)).to eq(["https://feed.test/twice"])
      expect(enqueued_page_ids.length).to eq(1)
    end

    it "skips items that already have a page" do
      existing = create_page("https://feed.test/old", state: "processed")
      stub_feed(%w[Old https://feed.test/old], %w[New https://feed.test/new])

      described_class.new(review_feed).perform

      expect(WebPageForReview.where.not(id: existing.id).pluck(:url)).to eq(
        ["https://feed.test/new"]
      )
      expect(existing.reload.state).to eq("processed")
      expect(enqueued_page_ids.length).to eq(1)
    end

    it "skips items that already have an ink review" do
      allow(Resolv).to receive(:getaddresses).with("reviewed.test").and_return(["93.184.216.34"])
      create(:ink_review, url: "https://reviewed.test/kon-peki")
      stub_feed(%w[Reviewed https://reviewed.test/kon-peki])

      described_class.new(review_feed).perform

      expect(WebPageForReview.count).to eq(0)
      expect(enqueued_page_ids).to be_empty
    end

    it "resolves relative item links against the redirected feed URL" do
      stub_request(:get, feed_url).to_return(
        status: 301,
        headers: {
          "Location" => "https://feed.test/blog/feed/"
        }
      )
      stub_request(:get, "https://feed.test/blog/feed/").to_return(
        status: 200,
        body: rss(%w[Relative kon-peki])
      )

      described_class.new(review_feed).perform

      expect(WebPageForReview.pluck(:url)).to eq(["https://feed.test/blog/feed/kon-peki"])
    end

    it "links existing pages without a feed to the feed" do
      unlinked = create_page("https://feed.test/unlinked")
      other_feed = create(:review_feed)
      linked_elsewhere = create_page("https://feed.test/elsewhere", review_feed: other_feed)
      not_in_feed = create_page("https://feed.test/not-in-feed")
      stub_feed(%w[Unlinked https://feed.test/unlinked], %w[Elsewhere https://feed.test/elsewhere])

      described_class.new(review_feed).perform

      expect(unlinked.reload.review_feed).to eq(review_feed)
      expect(linked_elsewhere.reload.review_feed).to eq(other_feed)
      expect(not_in_feed.reload.review_feed).to be_nil
    end
  end

  describe "back catalog" do
    let(:review_feed) { create(:review_feed, feed_url:, back_catalog_imported: false) }

    it "records the items of a new feed as skipped and enqueues nothing" do
      stub_feed(%w[First https://feed.test/first], %w[Second https://feed.test/second])

      expect(described_class.new(review_feed).perform).to be(true)

      expect(
        WebPageForReview.order(:id).map { |page| [page.url, page.state, page.data["search_term"]] }
      ).to eq(
        [%w[https://feed.test/first skipped First], %w[https://feed.test/second skipped Second]]
      )
      expect(WebPageForReview.pluck(:review_feed_id).uniq).to eq([review_feed.id])
      expect(enqueued_page_ids).to be_empty
      expect(review_feed.reload.back_catalog_imported).to be(true)
    end

    it "leaves items that already have a page alone" do
      existing = create_page("https://feed.test/first", state: "processed")
      stub_feed(%w[First https://feed.test/first])

      described_class.new(review_feed).perform

      expect(WebPageForReview.sole).to eq(existing)
      expect(existing.reload).to have_attributes(state: "processed", review_feed:)
    end

    it "processes items published after the first fetch" do
      stub_feed(%w[First https://feed.test/first])
      described_class.new(review_feed).perform
      stub_feed(["Second ink", "https://feed.test/second"], %w[First https://feed.test/first])

      described_class.new(review_feed).perform

      expect(WebPageForReview.find_by(url: "https://feed.test/second").state).to eq("pending")
      expect(WebPageForReview.find_by(url: "https://feed.test/first").state).to eq("skipped")
      expect(enqueued_page_ids.length).to eq(1)
    end

    it "keeps the back catalog pending when the first fetch fails" do
      stub_failure

      described_class.new(review_feed).perform

      expect(review_feed.reload.back_catalog_imported).to be(false)
    end
  end

  describe "pre-filter" do
    let(:review_feed) { create(:review_feed, feed_url:, back_catalog_imported: true) }

    it "creates a pending page for a matching item, enqueues it and records the match" do
      create(:brand_cluster, name: "Diamine")
      stub_feed(["Diamine Oxblood", "https://feed.test/oxblood"])

      described_class.new(review_feed).perform

      page = WebPageForReview.sole
      expect(page).to have_attributes(state: "pending", review_feed:)
      expect(page.data).to eq(
        "search_term" => "Diamine Oxblood",
        "filter_rule" => "brand",
        "filter_text" => "Diamine"
      )
      expect(enqueued_page_ids).to eq([page.id])
    end

    it "passes an item through its category" do
      stub_feed(["Weekend notes", "https://feed.test/notes", "Ink Reviews"])

      described_class.new(review_feed).perform

      page = WebPageForReview.sole
      expect(page).to have_attributes(state: "pending", review_feed:)
      expect(page.data).to eq(
        "search_term" => "Weekend notes",
        "filter_rule" => "category",
        "filter_text" => "Ink Reviews"
      )
      expect(enqueued_page_ids).to eq([page.id])
    end

    it "records an item that does not match as filtered without enqueueing it" do
      stub_feed(["My trip to Japan", "https://feed.test/japan"])

      described_class.new(review_feed).perform

      expect(WebPageForReview.sole).to have_attributes(
        state: "filtered",
        review_feed:,
        data: {
          "search_term" => "My trip to Japan"
        }
      )
      expect(enqueued_page_ids).to be_empty
    end

    it "builds the filter once per run" do
      allow(ReviewFeedFilter).to receive(:new).and_call_original
      stub_feed(%w[Swatches https://feed.test/a], %w[Holiday https://feed.test/b])

      described_class.new(review_feed).perform

      expect(ReviewFeedFilter).to have_received(:new).once
      expect(WebPageForReview.order(:url).pluck(:state)).to eq(%w[pending filtered])
    end

    it "does not build the filter when there is no new item" do
      allow(ReviewFeedFilter).to receive(:new)
      create_page("https://feed.test/old", state: "processed")
      stub_feed(%w[Old https://feed.test/old])

      described_class.new(review_feed).perform

      expect(ReviewFeedFilter).not_to have_received(:new)
    end

    it "does not filter the items of a curated feed" do
      review_feed.update!(curated: true)
      allow(ReviewFeedFilter).to receive(:new)
      stub_feed(["My trip to Japan", "https://feed.test/japan"])

      described_class.new(review_feed).perform

      page = WebPageForReview.sole
      expect(page).to have_attributes(
        state: "pending",
        data: {
          "search_term" => "My trip to Japan"
        }
      )
      expect(enqueued_page_ids).to eq([page.id])
      expect(ReviewFeedFilter).not_to have_received(:new)
    end

    it "skips the back catalog of a new feed without filtering it" do
      review_feed.update!(back_catalog_imported: false)
      allow(ReviewFeedFilter).to receive(:new)
      stub_feed(["Diamine Oxblood", "https://feed.test/oxblood"])

      described_class.new(review_feed).perform

      expect(WebPageForReview.sole.state).to eq("skipped")
      expect(ReviewFeedFilter).not_to have_received(:new)
    end
  end

  describe "success" do
    it "resets the failure fields and records the fetch" do
      review_feed.update!(failure_count: 5, first_failed_at: 1.day.ago, last_error: "boom")
      stub_feed

      freeze_time do
        described_class.new(review_feed).perform

        expect(review_feed.reload).to have_attributes(
          failure_count: 0,
          first_failed_at: nil,
          last_error: nil,
          last_fetched_at: Time.current,
          last_attempted_at: Time.current,
          state: "active"
        )
      end
    end

    it "turns a failing feed active again" do
      review_feed.update!(state: "failing", failure_count: 80, first_failed_at: 4.days.ago)
      stub_feed

      described_class.new(review_feed).perform

      expect(review_feed.reload).to have_attributes(state: "active", failure_count: 0)
    end
  end

  describe "empty feed" do
    let(:start) { Time.zone.local(2026, 11, 1, 6, 0) }
    let(:notified_at) { [] }

    before { allow(Honeybadger).to receive(:notify) { notified_at << Time.current } }

    def fetch_at(time, *items)
      stub_feed(*items)
      travel_to(time) { described_class.new(review_feed.reload).perform }
    end

    def fetch_every_six_hours(from:, to:)
      time = from
      while time <= to
        fetch_at(time)
        time += 6.hours
      end
    end

    it "starts an empty streak on a successful fetch without items" do
      fetch_at(start)

      expect(review_feed.reload.empty_since).to eq(start)
    end

    it "keeps the start of the streak on further fetches without items" do
      review_feed.update!(empty_since: start)

      fetch_at(start + 2.days)

      expect(review_feed.reload.empty_since).to eq(start)
    end

    it "ends the streak on a fetch with items" do
      review_feed.update!(empty_since: start)

      fetch_at(start + 2.days, %w[Back https://feed.test/back])

      expect(review_feed.reload.empty_since).to be_nil
    end

    it "keeps the streak on a failed fetch" do
      review_feed.update!(empty_since: start)
      stub_failure

      travel_to(start + 2.days) { described_class.new(review_feed).perform }

      expect(review_feed.reload.empty_since).to eq(start)
    end

    it "does not start a streak on a failed fetch" do
      stub_failure

      described_class.new(review_feed).perform

      expect(review_feed.reload.empty_since).to be_nil
    end

    it "notifies Honeybadger once, on the first empty fetch after EMPTY_AFTER" do
      fetch_every_six_hours(from: start, to: start + ReviewFeed::EMPTY_AFTER + 3.days)

      expect(notified_at).to eq([start + ReviewFeed::EMPTY_AFTER + 6.hours])
      expect(Honeybadger).to have_received(:notify).with(
        "Review feed #{review_feed.host} empty since #{start.iso8601}",
        error_class: "ReviewFeedEmpty",
        fingerprint: "review_feed_empty_#{review_feed.id}",
        context: {
          review_feed_id: review_feed.id,
          host: review_feed.host,
          feed_url:,
          empty_since: start.iso8601
        }
      )
    end

    it "notifies on the first empty fetch after failed fetches that straddled EMPTY_AFTER" do
      fetch_at(start)
      stub_failure
      travel_to(start + ReviewFeed::EMPTY_AFTER) { described_class.new(review_feed).perform }

      fetch_at(start + ReviewFeed::EMPTY_AFTER + 1.day)

      expect(notified_at).to eq([start + ReviewFeed::EMPTY_AFTER + 1.day])
    end

    it "does not notify for a feed that gets items again" do
      fetch_at(start)
      fetch_at(start + ReviewFeed::EMPTY_AFTER - 1.hour, %w[Back https://feed.test/back])

      fetch_every_six_hours(from: start + ReviewFeed::EMPTY_AFTER, to: start + 10.days)

      expect(notified_at).to be_empty
    end

    it "notifies again for a new streak after the feed had items" do
      fetch_every_six_hours(from: start, to: start + 8.days)
      fetch_at(start + 9.days, %w[Back https://feed.test/back])
      restart = start + 10.days

      fetch_every_six_hours(from: restart, to: restart + 8.days)

      expect(notified_at).to eq(
        [start + ReviewFeed::EMPTY_AFTER + 6.hours, restart + ReviewFeed::EMPTY_AFTER + 6.hours]
      )
    end
  end

  describe "admin changes during a run" do
    def ignore_during_fetch(response)
      stub_request(:get, feed_url).to_return do
        ReviewFeed.where(id: review_feed.id).update_all(state: "ignored")
        response
      end
    end

    it "keeps a feed ignored that was ignored while a failing feed was fetched" do
      review_feed.update!(state: "failing", first_failed_at: 4.days.ago, failure_count: 80)
      ignore_during_fetch(status: 200, body: rss)

      described_class.new(review_feed).perform

      expect(review_feed.reload).to have_attributes(state: "ignored", failure_count: 0)
    end

    it "keeps a feed ignored that was ignored while its fetch failed" do
      review_feed.update!(failure_count: 72, first_failed_at: 4.days.ago)
      ignore_during_fetch(status: 503)

      described_class.new(review_feed).perform

      expect(review_feed.reload).to have_attributes(state: "ignored", failure_count: 73)
      expect(Honeybadger).not_to have_received(:notify)
    end
  end

  describe "failure" do
    it "records the first failure without raising" do
      stub_failure

      freeze_time do
        expect(described_class.new(review_feed).perform).to be(false)

        expect(review_feed.reload).to have_attributes(
          failure_count: 1,
          first_failed_at: Time.current,
          last_error: "Faraday::ServerError: status 503",
          last_attempted_at: Time.current,
          last_fetched_at: nil,
          state: "active"
        )
      end
      expect(Honeybadger).not_to have_received(:notify)
    end

    it "keeps the start of the failure streak and counts further failures" do
      first_failed_at = 2.days.ago.round
      review_feed.update!(failure_count: 3, first_failed_at:)
      stub_failure

      described_class.new(review_feed).perform

      expect(review_feed.reload).to have_attributes(failure_count: 4, first_failed_at:)
    end

    it "records a connection error" do
      stub_request(:get, feed_url).to_raise(SocketError.new("getaddrinfo failed"))

      described_class.new(review_feed).perform

      expect(review_feed.reload.last_error).to eq("Faraday::ConnectionFailed: getaddrinfo failed")
    end

    it "records a body that is not a feed" do
      stub_request(:get, feed_url).to_return(status: 200, body: "<html>moved</html>")

      described_class.new(review_feed).perform

      expect(review_feed.reload).to have_attributes(
        failure_count: 1,
        last_error: "FeedParser::Error: No valid parser for XML."
      )
      expect(WebPageForReview.count).to eq(0)
    end

    it "stays active while the streak is shorter than FAILING_AFTER" do
      review_feed.update!(
        failure_count: 70,
        first_failed_at: (ReviewFeed::FAILING_AFTER - 1.hour).ago
      )
      stub_failure

      described_class.new(review_feed).perform

      expect(review_feed.reload.state).to eq("active")
      expect(Honeybadger).not_to have_received(:notify)
    end

    it "turns failing and notifies Honeybadger once the streak is older than FAILING_AFTER" do
      review_feed.update!(
        failure_count: 72,
        first_failed_at: (ReviewFeed::FAILING_AFTER + 1.hour).ago
      )
      stub_failure

      described_class.new(review_feed).perform

      expect(review_feed.reload).to have_attributes(state: "failing", failure_count: 73)
      expect(Honeybadger).to have_received(:notify).once.with(
        a_string_including(review_feed.host),
        error_class: "ReviewFeedFailing",
        fingerprint: "review_feed_failing_#{review_feed.id}",
        context: {
          review_feed_id: review_feed.id,
          feed_url:,
          failure_count: 73,
          last_error: "Faraday::ServerError: status 503"
        }
      )
    end

    it "does not notify again on further failures of a failing feed" do
      review_feed.update!(state: "failing", failure_count: 73, first_failed_at: 4.days.ago)
      stub_failure

      described_class.new(review_feed).perform

      expect(review_feed.reload).to have_attributes(state: "failing", failure_count: 74)
      expect(Honeybadger).not_to have_received(:notify)
    end

    it "turns non-curated feeds failing too" do
      review_feed.update!(curated: false, failure_count: 18, first_failed_at: 4.days.ago)
      stub_failure

      described_class.new(review_feed).perform

      expect(review_feed.reload.state).to eq("failing")
      expect(Honeybadger).to have_received(:notify).once
    end
  end

  def create_page(url, state: "pending", review_feed: nil)
    WebPageForReview.create!(url:, state:, review_feed:)
  end
end
