class RefreshLeaderBoards
  include Sidekiq::Worker

  sidekiq_options queue: "leaderboards"

  def perform
    LeaderBoard::TYPES.each { |type| RefreshLeaderBoard.perform_async(type) }
  end
end
