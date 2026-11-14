class FetchReviewFeed
  def initialize(review_feed)
    self.review_feed = review_feed
  end

  def perform
    review_feed.update!(last_attempted_at: Time.current)
    items = fetch_items
  rescue Faraday::Error, FeedParser::Error => e
    record_failure(e)
    false
  else
    import(items)
    record_success
    true
  end

  private

  attr_accessor :review_feed

  def fetch_items
    response = SafeHttp.get(review_feed.feed_url)
    FeedParser.new(response.body, response.final_url).perform.uniq { |item| item[:url] }
  end

  def import(items)
    link_existing_pages(items)
    if review_feed.back_catalog_imported
      items_without_page_or_review(items).each { |item| process(item) }
    else
      skip_back_catalog(items)
    end
  end

  def link_existing_pages(items)
    WebPageForReview.where(url: urls(items), review_feed_id: nil).update_all(
      review_feed_id: review_feed.id
    )
  end

  def skip_back_catalog(items)
    existing = WebPageForReview.where(url: urls(items)).pluck(:url).to_set
    items
      .reject { |item| existing.include?(item[:url]) }
      .each { |item| create_page(item, "skipped") }
    review_feed.update!(back_catalog_imported: true)
  end

  def items_without_page_or_review(items)
    known = WebPageForReview.where(url: urls(items)).pluck(:url).to_set
    known.merge(InkReview.where(url: urls(items)).pluck(:url))
    items.reject { |item| known.include?(item[:url]) }
  end

  def process(item)
    page = create_page(item, "pending")
    FetchReviews::ProcessWebPageForReview.perform_async(page.id)
  end

  def create_page(item, state)
    WebPageForReview.create!(
      url: item[:url],
      state:,
      review_feed:,
      data: {
        search_term: item[:title]
      }
    )
  end

  def urls(items)
    items.map { |item| item[:url] }
  end

  def record_success
    review_feed.state = "active" if review_feed.state == "failing"
    review_feed.update!(
      failure_count: 0,
      first_failed_at: nil,
      last_error: nil,
      last_fetched_at: Time.current
    )
  end

  def record_failure(error)
    review_feed.first_failed_at ||= Time.current
    review_feed.failure_count += 1
    review_feed.last_error = error_message(error)
    starts_failing = review_feed.state == "active" && failing_long_enough?
    review_feed.state = "failing" if starts_failing
    review_feed.save!
    notify_failing if starts_failing
  end

  def failing_long_enough?
    review_feed.first_failed_at < ReviewFeed::FAILING_AFTER.ago
  end

  def error_message(error)
    status = error.try(:response_status)
    [error.class.name, status && "status #{status}", error.message.presence].compact.join(": ")
  end

  def notify_failing
    Honeybadger.notify(
      "Review feed #{review_feed.host} failing since #{review_feed.first_failed_at.iso8601}",
      error_class: "ReviewFeedFailing",
      context: {
        review_feed_id: review_feed.id,
        feed_url: review_feed.feed_url,
        failure_count: review_feed.failure_count,
        last_error: review_feed.last_error
      }
    )
  end
end
