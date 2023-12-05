class RefreshLeaderBoardRows
  include Sidekiq::Worker

  sidekiq_options queue: "leaderboards"

  def perform
    User.active.find_each do |user|
      RefreshLeaderBoardRowsForUser.perform_async(user.id)
    end
  end
end
