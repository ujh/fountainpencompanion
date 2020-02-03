class AddPrivateCommentToCollectedInks < ActiveRecord::Migration[6.0]
  def change
    add_column :collected_inks, :private_comment, :text
  end
end
