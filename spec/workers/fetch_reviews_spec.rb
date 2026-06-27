require "rails_helper"

describe FetchReviews do
  it "enqueues a GenericRss job per feed and a YoutubeChannel job per channel" do
    channel = create(:you_tube_channel)
    allow(YouTubeChannel).to receive(:channel_ids_for_reviews).and_return([channel.channel_id])

    subject.perform

    rss_args = FetchReviews::GenericRss.jobs.map { |j| j["args"] }
    expect(rss_args.length).to eq(13)
    expect(FetchReviews::YoutubeChannel.jobs.map { |j| j["args"] }).to eq([[channel.channel_id]])
  end

  it "staggers the source jobs by STAGGER_INTERVAL seconds" do
    channel = create(:you_tube_channel)
    allow(YouTubeChannel).to receive(:channel_ids_for_reviews).and_return([channel.channel_id])

    subject.perform

    now = Time.now.to_f
    interval = FetchReviews::STAGGER_INTERVAL
    rss_jobs = FetchReviews::GenericRss.jobs
    expect(rss_jobs.first["at"]).to be_nil # first feed runs immediately
    expect(rss_jobs.last["at"] - now).to be_within(2).of(interval * 12) # 13th feed

    # YouTube channels are staggered after the feeds
    yt_job = FetchReviews::YoutubeChannel.jobs.first
    expect(yt_job["at"] - now).to be_within(2).of(interval * 13)
  end
end
