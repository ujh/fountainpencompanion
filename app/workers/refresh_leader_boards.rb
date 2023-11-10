class RefreshLeaderBoards
  include Sidekiq::Worker

  sidekiq_options queue: "leaderboards"

  def perform
    LeaderBoard::WORKERS.each { |worker| worker.perform_async }
  end
end
