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
    record_success(items)
    true
  end

  private

  attr_accessor :review_feed, :review_feed_filter

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
    existing = existing_page_urls(items)
    items
      .reject { |item| existing.include?(item[:url]) }
      .each { |item| create_page(item, "skipped") }
    review_feed.update!(back_catalog_imported: true)
  end

  def items_without_page_or_review(items)
    known = existing_page_urls(items).merge(InkReview.where(url: urls(items)).pluck(:url))
    items.reject { |item| known.include?(item[:url]) }
  end

  def existing_page_urls(items)
    WebPageForReview.where(url: urls(items)).pluck(:url).to_set
  end

  def process(item)
    if review_feed.curated
      enqueue(create_page(item, "pending"))
    elsif (match = filter.match(item))
      enqueue(create_page(item, "pending", filter_rule: match.rule, filter_text: match.text))
    else
      create_page(item, "filtered")
    end
  end

  def filter
    self.review_feed_filter ||= ReviewFeedFilter.new
  end

  def enqueue(page)
    FetchReviews::ProcessWebPageForReview.perform_async(page.id)
  end

  def create_page(item, state, data = {})
    WebPageForReview.create!(
      url: item[:url],
      state:,
      review_feed:,
      data: {
        search_term: item[:title],
        **data
      }
    )
  end

  def urls(items)
    items.map { |item| item[:url] }
  end

  def record_success(items)
    transition_state(from: "failing", to: "active")
    previous_fetch_at = review_feed.last_fetched_at
    review_feed.update!(
      **ReviewFeed::FAILURE_RESET,
      last_fetched_at: Time.current,
      empty_since: items.empty? ? (review_feed.empty_since || Time.current) : nil
    )
    notify_empty if newly_stale_empty?(previous_fetch_at)
  end

  def newly_stale_empty?(previous_fetch_at)
    review_feed.stale_empty? &&
      (previous_fetch_at.nil? || !review_feed.stale_empty?(previous_fetch_at))
  end

  def record_failure(error)
    review_feed.first_failed_at ||= Time.current
    review_feed.failure_count += 1
    review_feed.last_error = error_message(error)
    review_feed.save!
    notify_failing if failing_long_enough? && transition_state(from: "active", to: "failing")
  end

  def transition_state(from:, to:)
    ReviewFeed.where(id: review_feed.id, state: from).update_all(
      state: to,
      updated_at: Time.current
    ) == 1
  end

  def failing_long_enough?
    review_feed.first_failed_at < ReviewFeed::FAILING_AFTER.ago
  end

  def error_message(error)
    status = error.try(:response_status)
    [error.class.name, status && "status #{status}", error.message.presence].compact.join(": ")
  end

  def notify_empty
    Honeybadger.notify(
      "Review feed #{review_feed.host} empty since #{review_feed.empty_since.iso8601}",
      error_class: "ReviewFeedEmpty",
      fingerprint: "review_feed_empty_#{review_feed.id}",
      context: {
        review_feed_id: review_feed.id,
        host: review_feed.host,
        feed_url: review_feed.feed_url,
        empty_since: review_feed.empty_since.iso8601
      }
    )
  end

  def notify_failing
    Honeybadger.notify(
      "Review feed #{review_feed.host} failing since #{review_feed.first_failed_at.iso8601}",
      error_class: "ReviewFeedFailing",
      fingerprint: "review_feed_failing_#{review_feed.id}",
      context: {
        review_feed_id: review_feed.id,
        feed_url: review_feed.feed_url,
        failure_count: review_feed.failure_count,
        last_error: review_feed.last_error
      }
    )
  end
end
