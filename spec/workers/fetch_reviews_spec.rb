require "rails_helper"

describe FetchReviews do
  include ActiveSupport::Testing::TimeHelpers

  before { allow(YouTubeChannel).to receive(:channel_ids_for_reviews).and_return([]) }

  def at_hour(hour, &)
    travel_to(Time.utc(2026, 11, 14, hour, 5), &)
  end

  def enqueued_feed_ids
    FetchReviews::GenericRss.jobs.map { |job| job["args"].first }
  end

  it "enqueues a GenericRss job per due feed and a YoutubeChannel job per channel" do
    feed = create(:review_feed, :curated)
    channel = create(:you_tube_channel)
    allow(YouTubeChannel).to receive(:channel_ids_for_reviews).and_return([channel.channel_id])

    subject.perform

    expect(enqueued_feed_ids).to eq([feed.id])
    expect(FetchReviews::YoutubeChannel.jobs.map { |j| j["args"] }).to eq([[channel.channel_id]])
  end

  def delays
    now = Time.now.to_f
    (FetchReviews::GenericRss.jobs + FetchReviews::YoutubeChannel.jobs).map do |job|
      job["at"] ? job["at"] - now : 0
    end
  end

  it "staggers a few source jobs by STAGGER_INTERVAL seconds, feeds first" do
    create_list(:review_feed, 2, :curated)
    channel = create(:you_tube_channel)
    allow(YouTubeChannel).to receive(:channel_ids_for_reviews).and_return([channel.channel_id])

    subject.perform

    interval = FetchReviews::STAGGER_INTERVAL
    expect(FetchReviews::GenericRss.jobs.first["at"]).to be_nil
    expect(delays).to match([0, be_within(2).of(interval), be_within(2).of(interval * 2)])
  end

  it "spreads many source jobs evenly over SPREAD_WINDOW, feeds first" do
    create_list(:review_feed, 200, :curated)
    channel_ids = (1..40).map { |i| "channel-#{i}" }
    allow(YouTubeChannel).to receive(:channel_ids_for_reviews).and_return(channel_ids)

    subject.perform

    interval = FetchReviews::SPREAD_WINDOW / 240.0
    expect(interval).to be < FetchReviews::STAGGER_INTERVAL
    expect(delays).to match(Array.new(240) { |i| be_within(2).of(i * interval) })
    expect(delays.last).to be < FetchReviews::SPREAD_WINDOW
    expect(FetchReviews::YoutubeChannel.jobs.map { |job| job["args"].first }).to eq(channel_ids)
    expect(FetchReviews::YoutubeChannel.jobs.first["at"]).to be >
      FetchReviews::GenericRss.jobs.last["at"]
  end

  it "uses the UTC hour" do
    feed = create(:review_feed, state: "failing")
    due_hour = feed.id % 24

    Time.use_zone("Tokyo") { at_hour(due_hour) { subject.perform } }

    expect(enqueued_feed_ids).to eq([feed.id])
  end

  it "does not fetch feeds that are not fetchable" do
    create(:review_feed, :curated, :ignored)
    create(:review_feed, :curated, :no_feed)
    create(:review_feed, :curated, state: "duplicate", feed_url: nil)

    (0..23).each { |hour| at_hour(hour) { subject.perform } }

    expect(FetchReviews::GenericRss.jobs).to be_empty
  end
end
