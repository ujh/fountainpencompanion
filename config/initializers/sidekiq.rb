require 'sidekiq'
require 'sidekiq-scheduler'

# Load schedule from separate file
Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq_schedule.yml', __FILE__))
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

# Heroku uses self signed certificates for their premium Redis
Sidekiq.configure_server do |config|
  config.redis = { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end

Sidekiq.configure_client do |config|
  config.redis = { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end
