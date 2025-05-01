class RunAgent
  include Sidekiq::Worker
  sidekiq_options queue: "agents"

  def perform(klass, *)
    klass.constantize.new(*).perform
  end
end
