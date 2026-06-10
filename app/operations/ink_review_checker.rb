class InkReviewChecker
  def initialize(ink_review)
    self.ink_review = ink_review
  end

  def perform
    page_data = Unfurler.new(ink_review.url).perform
    unless image_reachable?(page_data.image)
      record_failure("Image unreachable")
      return
    end

    ink_review.assign_attributes(
      title: page_data.title,
      description: page_data.description,
      image: page_data.image,
      author: page_data.author
    )
    if ink_review.save
      record_success
    else
      error_message = ink_review.errors.full_messages.join(", ")
      ink_review.reload
      record_failure(error_message)
    end
  rescue URI::InvalidURIError, Faraday::Error, Google::Apis::Error => e
    record_failure(e.message)
  end

  private

  attr_accessor :ink_review

  def image_reachable?(url)
    return false if url.blank?
    (200..299).cover?(SafeHttp.head(url).status)
  rescue Faraday::Error, URI::InvalidURIError
    false
  end

  def record_success
    ink_review.update!(check_count: 0, next_check_at: InkReview::CHECK_INTERVAL.from_now)
    ink_review.ink_review_checks.create!(result: "success")
  end

  def record_failure(message)
    new_count = ink_review.check_count + 1
    if new_count >= InkReview::MAX_FAILED_CHECKS
      ink_review.update!(check_count: new_count, next_check_at: nil)
      ink_review.ink_review_checks.create!(result: "removed", error_message: message)
    else
      ink_review.update!(check_count: new_count, next_check_at: InkReview::RETRY_INTERVAL.from_now)
      ink_review.ink_review_checks.create!(result: "error", error_message: message)
    end
  end
end
