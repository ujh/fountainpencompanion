require "rails_helper"

describe "config/sidekiq_schedule.yml" do
  let(:schedule) { YAML.load_file(Rails.root.join("config/sidekiq_schedule.yml")) }

  it "names an existing Sidekiq worker in every entry" do
    schedule.each_value { |entry| expect(entry["class"].constantize).to include(Sidekiq::Worker) }
  end

  it "discovers review feeds once a day" do
    expect(schedule["discover_review_feeds"]).to include(
      "class" => "DiscoverReviewFeeds",
      "cron" => "20 3 * * *"
    )
  end
end
