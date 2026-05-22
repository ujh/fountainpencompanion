require "sidekiq_alive"

SidekiqAlive.setup do |config|
  config.host = ENV.fetch("SIDEKIQ_ALIVE_HOST", "127.0.0.1")
  config.port = Integer(ENV.fetch("SIDEKIQ_ALIVE_PORT", 7433))
  config.time_to_live = 5 * 60
end
