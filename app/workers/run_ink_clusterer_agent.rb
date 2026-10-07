class RunInkClustererAgent
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker

  sidekiq_throttle concurrency: { limit: 1 }
  sidekiq_options queue: "agents", retry: 3
  sidekiq_retry_in do |_count, exception|
    case exception
    when RubyLLM::BadRequestError, RubyLLM::ContextLengthExceededError
      :kill
    end
  end

  def perform(klass, *)
    klass.constantize.new(*).perform
  end
end
