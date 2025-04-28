class RunAgent
  include Sidekiq::Worker

  def perform(klass, *)
    klass.constantize.new(*).perform
  end
end
