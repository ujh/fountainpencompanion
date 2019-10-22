module ApplicationHelper
  def leaderboard_index(method)
    index = LeaderBoard.send(method).find_index do |entry|
      entry[:id] == current_user.id
    end
    return index.succ if index
  end
end
