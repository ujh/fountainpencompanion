class RunInkClustererAgent
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker
  include LlmJobRetries

  sidekiq_throttle concurrency: { limit: 1 }
  sidekiq_options queue: "agents"

  def perform(klass, *)
    klass.constantize.new(*).perform
  end
end
