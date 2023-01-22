class RefreshLeaderBoard
  include Sidekiq::Worker

  sidekiq_options queue: "leaderboards"

  def perform(type)
    LeaderBoard.refresh!(type)
  end
end
