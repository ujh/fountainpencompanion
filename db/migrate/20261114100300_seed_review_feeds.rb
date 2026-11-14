class SeedReviewFeeds < ActiveRecord::Migration[8.1]
  CURATED_FEED_URLS = %w[
    https://inkcrediblecolours.com/feed/
    https://inksharks.blogspot.com/feeds/posts/default?alt=rss
    https://inkyfountainpens.wordpress.com/feed/
    https://mountainofink.com/?format=rss
    https://mymanymuses.com/category/ink/feed/
    https://nickstewart.ink/feed
    https://penaddict.com/blog?format=rss
    https://toomanypurples.blogspot.com/feeds/posts/default?alt=rss
    https://wondernaut.wordpress.com/category/ink-review/feed/
    https://writingatlarge.com/feed/
    https://www.fountainpenpharmacist.com/feeds/posts/default?alt=rss
    https://www.inkyinspirations.com/inkreviews?format=rss
    https://www.wellappointeddesk.com/category/ink-review/feed/
  ].freeze

  IGNORED_HOSTS = %w[gentlemanstationer.com].freeze

  PAGE_HOST_SQL = <<~SQL.squish
    regexp_replace(
      lower(substring(web_page_for_reviews.url from '^[A-Za-z][A-Za-z0-9+.-]*://([^/?#:]+)')),
      '^www\\.',
      ''
    )
  SQL

  def up
    safety_assured do
      CURATED_FEED_URLS.each { |feed_url| execute <<~SQL }
          INSERT INTO review_feeds
            (host, feed_url, state, curated, back_catalog_imported, created_at, updated_at)
          VALUES
            (#{quote(host_of(feed_url))}, #{quote(feed_url)}, 'active', true, true, NOW(), NOW())
        SQL

      IGNORED_HOSTS.each { |host| execute <<~SQL }
          INSERT INTO review_feeds (host, state, created_at, updated_at)
          VALUES (#{quote(host)}, 'ignored', NOW(), NOW())
        SQL

      execute <<~SQL
        UPDATE web_page_for_reviews
        SET review_feed_id = review_feeds.id
        FROM review_feeds
        WHERE review_feeds.feed_url IS NOT NULL
          AND review_feeds.host = #{PAGE_HOST_SQL}
      SQL
    end
  end

  def down
    hosts = (CURATED_FEED_URLS.map { |feed_url| host_of(feed_url) } + IGNORED_HOSTS)
    host_list = hosts.map { |host| quote(host) }.join(", ")

    safety_assured do
      execute <<~SQL
        UPDATE web_page_for_reviews
        SET review_feed_id = NULL
        WHERE review_feed_id IN (SELECT id FROM review_feeds WHERE host IN (#{host_list}))
      SQL
      execute "DELETE FROM review_feeds WHERE host IN (#{host_list})"
    end
  end

  private

  def host_of(url)
    URI.parse(url).host.downcase.delete_prefix("www.")
  end

  def quote(value)
    connection.quote(value)
  end
end
