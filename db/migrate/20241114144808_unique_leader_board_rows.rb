class UniqueLeaderBoardRows < ActiveRecord::Migration[8.0]
  def change
    LeaderBoardRow.delete_all

    safety_assured do
      add_index :leader_board_rows, %i[type user_id], unique: true
    end
  end
end
