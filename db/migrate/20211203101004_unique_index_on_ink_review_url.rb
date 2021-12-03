class UniqueIndexOnInkReviewUrl < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :ink_reviews, :url, unique: true, algorithm: :concurrently
  end
end
