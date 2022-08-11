class RefreshLeaderBoards
  include Sidekiq::Worker

  sidekiq_options queue: 'leaderboards'

  def perform
    LeaderBoard::TYPES.each do |type|
      RefreshLeaderBoard.perform_async(type)
    end
  end
end
