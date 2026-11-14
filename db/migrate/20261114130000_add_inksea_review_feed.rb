class AddInkseaReviewFeed < ActiveRecord::Migration[8.1]
  HOST = "inksea.pl"
  FEED_URL = "https://inksea.pl/ink/feed/"

  def up
    safety_assured { execute <<~SQL }
        INSERT INTO review_feeds
          (host, feed_url, state, curated, back_catalog_imported, created_at, updated_at)
        VALUES
          (#{quote(HOST)}, #{quote(FEED_URL)}, 'active', true, false, NOW(), NOW())
        ON CONFLICT DO NOTHING
      SQL
  end

  def down
    safety_assured { execute <<~SQL }
        UPDATE web_page_for_reviews
        SET review_feed_id = NULL
        WHERE review_feed_id IN (
          SELECT id FROM review_feeds WHERE host = #{quote(HOST)} AND feed_url = #{quote(FEED_URL)}
        )
      SQL
    safety_assured do
      execute "DELETE FROM review_feeds WHERE host = #{quote(HOST)} AND feed_url = #{quote(FEED_URL)}"
    end
  end

  private

  def quote(value)
    connection.quote(value)
  end
end
