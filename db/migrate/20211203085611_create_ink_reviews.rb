class CreateInkReviews < ActiveRecord::Migration[6.1]
  def change
    create_table :ink_reviews do |t|
      t.text :title, null: false
      t.text :url, null: false
      t.text :description
      t.text :image, null: false
      t.references :macro_cluster, foreign_key: true, null: false
      t.datetime :rejected_at
      t.datetime :approved_at

      t.timestamps
    end
  end
end
