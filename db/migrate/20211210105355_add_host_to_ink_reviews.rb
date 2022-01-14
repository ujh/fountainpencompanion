class AddHostToInkReviews < ActiveRecord::Migration[6.1]
  def change
    add_column :ink_reviews, :host, :text
  end
end
