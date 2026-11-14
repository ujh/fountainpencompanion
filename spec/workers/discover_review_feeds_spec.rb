require "rails_helper"
require "active_record/testing/query_assertions"

describe DiscoverReviewFeeds do
  include RSpec::Rails::MinitestAssertionAdapter
  include ActiveSupport::Testing::Assertions
  include ActiveRecord::Assertions::QueryAssertions

  def approved_reviews(host, count)
    count.times { |i| create(:ink_review, url: "https://#{host}/#{i}", approved_at: Time.current) }
  end

  def enqueued_hosts
    DiscoverReviewFeed.jobs.map { |job| job["args"].first }
  end

  it "enqueues a job per qualifying host and per no_feed row due for rediscovery" do
    approved_reviews("www.new.test", 3)
    approved_reviews("too-few.test", 2)
    create(:review_feed, :no_feed, host: "never-discovered.test", discovered_at: nil)
    create(:review_feed, :no_feed, host: "stale.test", discovered_at: 31.days.ago)
    create(:review_feed, :no_feed, host: "fresh.test", discovered_at: 1.day.ago)

    subject.perform

    expect(enqueued_hosts).to eq(%w[new.test never-discovered.test stale.test])
  end

  it "staggers the jobs by STAGGER_INTERVAL seconds" do
    approved_reviews("a.test", 3)
    approved_reviews("b.test", 3)
    create(:review_feed, :no_feed, host: "c.test", discovered_at: nil)

    subject.perform

    now = Time.now.to_f
    interval = described_class::STAGGER_INTERVAL
    jobs = DiscoverReviewFeed.jobs
    expect(jobs.first["at"]).to be_nil
    expect(jobs.second["at"] - now).to be_within(2).of(interval)
    expect(jobs.third["at"] - now).to be_within(2).of(interval * 2)
  end

  it "finds the hosts in two queries" do
    approved_reviews("a.test", 3)
    approved_reviews("b.test", 3)
    create_list(:review_feed, 2, :no_feed, discovered_at: nil)

    assert_queries_match(/SELECT/, count: 2) { subject.perform }
    expect(DiscoverReviewFeed.jobs.length).to eq(4)
  end

  it "uses the reviews queue" do
    expect(described_class.get_sidekiq_options["queue"]).to eq("reviews")
  end
end
