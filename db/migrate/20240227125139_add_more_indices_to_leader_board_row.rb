class AddMoreIndicesToLeaderBoardRow < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :leader_board_rows, :value, algorithm: :concurrently
  end
end
