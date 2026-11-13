class CreateInkReviewLoves < ActiveRecord::Migration[8.1]
  def change
    create_table :ink_review_loves do |t|
      t.references :ink_review, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :ink_review_loves, %i[ink_review_id user_id], unique: true
    add_column :ink_reviews, :loves_count, :integer, null: false, default: 0
  end
end
