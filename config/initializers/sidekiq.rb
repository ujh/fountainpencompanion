require "sidekiq"
require "sidekiq-scheduler"

# Load schedule from separate file
Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path("../sidekiq_schedule.yml", __dir__))
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

# Separate capsule for the leaderboard queue as it's super slow
Sidekiq.configure_server do |config|
  config.capsule("slow") do |cap|
    cap.concurrency = 1
    cap.queues = %w[leaderboards]
  end
end

# Separate capsule for the ink clustering as concurrency, especially during an
# import leads to weird behaviour
Sidekiq.configure_server do |config|
  config.capsule("ink-clusterer") do |cap|
    cap.concurrency = 1
    cap.queues = %w[agents-ink-clusterer]
  end
end
