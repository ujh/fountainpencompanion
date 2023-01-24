namespace :cache do
  desc "Refresh cached leaderboard data"
  task refresh_leaderboard: :environment do
    LeaderBoard.refresh!
  end
end
