class RunInkClustererAgent
  include Sidekiq::Worker

  sidekiq_options queue: "agents-ink-clusterer"

  def perform(klass, *)
    klass.constantize.new(*).perform
  end
end
