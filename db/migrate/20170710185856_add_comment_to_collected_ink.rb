class AddCommentToCollectedInk < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_inks, :comment, :text, default: ""
  end
end
