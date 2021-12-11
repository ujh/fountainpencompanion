class AddAuthorToInkReviews < ActiveRecord::Migration[6.1]
  def change
    add_column :ink_reviews, :author, :text
  end
end
