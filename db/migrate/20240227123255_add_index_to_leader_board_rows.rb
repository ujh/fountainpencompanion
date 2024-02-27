class AddIndexToLeaderBoardRows < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :leader_board_rows, :type, algorithm: :concurrently
  end
end
