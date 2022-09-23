require 'sidekiq'
require 'sidekiq-scheduler'

# Load schedule from separate file
Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq_schedule.yml', __FILE__))
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end
