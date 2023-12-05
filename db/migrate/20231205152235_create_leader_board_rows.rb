class CreateLeaderBoardRows < ActiveRecord::Migration[7.1]
  def change
    create_table :leader_board_rows do |t|
      t.references :user, foreign_key: true, null: false
      t.string :type
      t.integer :value
      t.timestamps
    end
  end
end
