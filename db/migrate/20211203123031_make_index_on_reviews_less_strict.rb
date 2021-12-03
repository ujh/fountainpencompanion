class MakeIndexOnReviewsLessStrict < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    remove_index :ink_reviews, :url, unique: true, algorithm: :concurrently
    add_index :ink_reviews, [:url, :macro_cluster_id], unique: true, algorithm: :concurrently
  end
end
