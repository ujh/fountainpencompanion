class RejectInkReview
  def initialize(ink_review, ignore_source: false)
    self.ink_review = ink_review
    self.ignore_source = ignore_source
    self.source_ignored = false
  end

  def perform
    InkReview.transaction do
      ink_review.reject!
      self.source_ignored = IgnoreReviewSource.new(ink_review).perform if ignore_source
    end
    true
  end

  def nothing_to_ignore?
    ignore_source && !source_ignored
  end

  private

  attr_accessor :ink_review, :ignore_source, :source_ignored
end
