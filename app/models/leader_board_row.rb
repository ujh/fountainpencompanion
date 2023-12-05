class LeaderBoardRow < ApplicationRecord
  belongs_to :user

  default_scope { includes(:user).order(value: :desc).where("value > 0") }

  def self.to_leader_board
    all.map do |row|
      {
        id: row.user.id,
        public_name: row.user.public_name,
        counter: row.value,
        patron: row.user.patron?
      }
    end
  end
end
