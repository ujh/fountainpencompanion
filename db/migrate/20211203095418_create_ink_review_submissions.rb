class CreateInkReviewSubmissions < ActiveRecord::Migration[6.1]
  def change
    create_table :ink_review_submissions do |t|
      t.text :url, null: false
      t.references :macro_cluster, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.references :ink_review, foreign_key: true

      t.timestamps
    end
  end
end
