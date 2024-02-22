class LeaderBoardRow < ApplicationRecord
  belongs_to :user

  def self.to_leader_board
    rows = includes(:user).order(value: :desc).where("value > 0")
    rows.map do |row|
      {
        id: row.user.id,
        public_name: row.user.public_name,
        counter: row.value,
        patron: row.user.patron?
      }
    end
  end
end
