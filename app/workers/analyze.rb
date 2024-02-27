class Analyze
  include Sidekiq::Worker

  def perform
    ActiveRecord::Base.connection.execute("ANALYZE")
  end
end
