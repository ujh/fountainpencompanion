class AddCommentToPens < ActiveRecord::Migration[5.1]
  def change
    add_column :pens, :comment, :string
  end
end
