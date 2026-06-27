class EnqueueInkReviewChecks
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  BATCH_SIZE = 100
  STAGGER_INTERVAL = 36 # seconds between enqueued jobs (~1 hour for full batch)

  def perform
    ids = InkReview.due_for_check.order(:next_check_at).limit(BATCH_SIZE).pluck(:id)

    # Claim the batch by pushing next_check_at past the stagger window so a
    # subsequent run (this worker is scheduled more often than the batch takes
    # to drain) does not re-enqueue reviews that are still in flight. The real
    # next_check_at is set by InkReviewChecker once each check actually runs.
    InkReview.where(id: ids).update_all(next_check_at: claim_until)

    ids.each_with_index { |id, i| CheckInkReview.perform_in((i * STAGGER_INTERVAL).seconds, id) }
  end

  private

  def claim_until
    (BATCH_SIZE * STAGGER_INTERVAL).seconds.from_now
  end
end
