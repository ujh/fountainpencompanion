class CreateReviewFeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :review_feeds do |t|
      t.text :host, null: false
      t.text :feed_url
      t.text :state, null: false
      t.boolean :curated, null: false, default: false
      t.boolean :back_catalog_imported, null: false, default: false
      t.integer :failure_count, null: false, default: 0
      t.datetime :first_failed_at
      t.text :last_error
      t.datetime :last_fetched_at
      t.datetime :last_attempted_at
      t.datetime :discovered_at
      t.timestamps

      t.index :host, unique: true
      t.index :feed_url, unique: true, where: "feed_url IS NOT NULL"
      t.check_constraint "state IN ('active', 'no_feed', 'ignored', 'failing', 'duplicate')",
                         name: "review_feeds_state_values"
      t.check_constraint "state NOT IN ('active', 'failing') OR feed_url IS NOT NULL",
                         name: "review_feeds_fetchable_feed_url"
    end
  end
end
