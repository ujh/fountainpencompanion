class TurnCollectedPenCommentIntoATextField < ActiveRecord::Migration[5.1]
  def change
    change_column :collected_pens, :comment, :text
  end
end
