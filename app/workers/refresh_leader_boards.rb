class RefreshLeaderBoards
  include Sidekiq::Worker

  def perform
    LeaderBoard.refresh!
  end
end
