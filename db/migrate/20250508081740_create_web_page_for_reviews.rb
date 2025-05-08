class CreateWebPageForReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :web_page_for_reviews do |t|
      t.text :state, default: "pending", index: true
      t.text :url, null: false, index: true
      t.jsonb :data, default: {}

      t.timestamps
    end
  end
end
