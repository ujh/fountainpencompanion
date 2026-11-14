require "rails_helper"

describe FetchReviews::GenericRss do
  let(:feed_url) { "https://feed.test/rss" }
  let!(:review_feed) { create(:review_feed, :curated, feed_url:) }

  before { allow(Resolv).to receive(:getaddresses).with("feed.test").and_return(["93.184.216.34"]) }

  def stub_feed(body)
    stub_request(:get, feed_url).to_return(status: 200, body:)
  end

  def rss_feed
    <<~XML
      <?xml version="1.0"?>
      <rss version="2.0"><channel><title>t</title><link>https://feed.test</link><description>d</description>
        <item><title>Pilot Kon-peki</title><link>https://feed.test/kon-peki</link></item>
      </channel></rss>
    XML
  end

  it "records a failure instead of following a feed redirect to an internal address" do
    allow(Resolv).to receive(:getaddresses).with("internal.test").and_return(["10.0.0.7"])
    stub_request(:get, feed_url).to_return(
      status: 302,
      headers: {
        "Location" => "http://internal.test/"
      }
    )
    internal = stub_request(:get, "http://internal.test/")

    described_class.new.perform(review_feed.id)

    expect(internal).not_to have_been_requested
    expect(WebPageForReview.count).to eq(0)
    expect(review_feed.reload.failure_count).to eq(1)
    expect(review_feed.last_error).to start_with("SafeHttp::BlockedError")
  end

  it "creates web pages for the items of the feed with the given id" do
    stub_feed(rss_feed)

    described_class.new.perform(review_feed.id)

    page = WebPageForReview.sole
    expect(page).to have_attributes(
      url: "https://feed.test/kon-peki",
      state: "pending",
      review_feed:,
      data: {
        "search_term" => "Pilot Kon-peki"
      }
    )
    expect(FetchReviews::ProcessWebPageForReview.jobs.map { |j| j["args"] }).to eq([[page.id]])
  end

  it "fetches the feed of a legacy job queued with the feed URL" do
    stub_feed(rss_feed)

    described_class.new.perform(feed_url)

    expect(WebPageForReview.sole).to have_attributes(
      url: "https://feed.test/kon-peki",
      review_feed:
    )
    expect(review_feed.reload.last_fetched_at).to be_present
  end

  it "returns quietly for a legacy feed URL that has no feed" do
    expect { described_class.new.perform("https://unknown.test/rss") }.not_to raise_error

    expect(WebPageForReview.count).to eq(0)
  end

  it "returns quietly for a feed that no longer exists" do
    id = review_feed.id
    review_feed.destroy!

    expect { described_class.new.perform(id) }.not_to raise_error

    expect(WebPageForReview.count).to eq(0)
  end

  it "does not fetch a feed that was ignored after the job was queued" do
    review_feed.update!(state: "ignored")

    described_class.new.perform(review_feed.id)

    expect(a_request(:get, feed_url)).not_to have_been_made
    expect(review_feed.reload.last_attempted_at).to be_nil
  end

  it "does not fetch an ignored feed from a legacy job queued with its feed URL" do
    review_feed.update!(state: "ignored")

    described_class.new.perform(feed_url)

    expect(a_request(:get, feed_url)).not_to have_been_made
    expect(review_feed.reload.last_attempted_at).to be_nil
  end

  it "fetches a failing feed" do
    review_feed.update!(state: "failing", first_failed_at: 4.days.ago, failure_count: 30)
    stub_feed(rss_feed)

    described_class.new.perform(review_feed.id)

    expect(review_feed.reload.state).to eq("active")
    expect(WebPageForReview.count).to eq(1)
  end

  it "creates web pages for an Atom feed" do
    stub_feed(<<~XML)
      <?xml version="1.0" encoding="utf-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Blog</title>
        <id>https://feed.test/</id>
        <updated>2026-11-01T00:00:00Z</updated>
        <entry>
          <title>Sailor Yama-dori</title>
          <id>tag:feed.test,2026:1</id>
          <updated>2026-11-01T00:00:00Z</updated>
          <link rel="replies" type="text/html" href="https://feed.test/yama-dori#comments"/>
          <link rel="alternate" type="text/html" href="https://feed.test/yama-dori"/>
        </entry>
      </feed>
    XML

    described_class.new.perform(review_feed.id)

    expect(WebPageForReview.sole).to have_attributes(
      url: "https://feed.test/yama-dori",
      state: "pending",
      data: {
        "search_term" => "Sailor Yama-dori"
      }
    )
  end
end
