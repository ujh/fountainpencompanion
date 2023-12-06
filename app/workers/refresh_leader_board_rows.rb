class RefreshLeaderBoardRows
  include Sidekiq::Worker

  sidekiq_options queue: "leaderboards"

  def perform
    User.active.find_each.with_index do |user, index|
      RefreshLeaderBoardRowsForUser.perform_in(index, user.id)
    end
  end
end
