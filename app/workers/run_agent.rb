class RunAgent
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker

  sidekiq_throttle concurrency: { limit: 2 }
  sidekiq_options queue: "agents"

  def perform(klass, *)
    klass.constantize.new(*).perform
  end
end
