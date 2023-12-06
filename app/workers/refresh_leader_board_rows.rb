class RefreshLeaderBoardRows
  include Sidekiq::Worker

  sidekiq_options queue: "leaderboards"

  def perform
    User.active.find_each.with_index do |user, index|
      offset = 2.minutes
      interval = index * 2 # once every two seconds
      RefreshLeaderBoardRowsForUser.perform_in(
        (offset + interval).to_i,
        user.id
      )
    end
  end
end
