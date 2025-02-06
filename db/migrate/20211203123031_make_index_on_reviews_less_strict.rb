class MakeIndexOnReviewsLessStrict < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :ink_reviews, %i[url macro_cluster_id], unique: true, algorithm: :concurrently
  end
end
