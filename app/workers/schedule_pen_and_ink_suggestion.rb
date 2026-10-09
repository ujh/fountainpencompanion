class SchedulePenAndInkSuggestion
  include Sidekiq::Worker

  sidekiq_options queue: "interactive", retry: 0

  def perform(
    user_id,
    suggestion_id,
    extra_user_input = nil,
    rejected_suggestions = [],
    enqueued_at = nil
  )
    result = nil
    queue_ms = queue_ms_since(enqueued_at)
    user = User.find(user_id)
    extra_user_input = nil unless extra_user_input_allowed?(user)
    result = PenAndInkSuggester.new(user, extra_user_input, rejected_suggestions, queue_ms:).perform
  ensure
    Rails.cache.write(
      suggestion_id,
      result || { message: PenAndInkSuggester::ERROR_MESSAGE },
      expires_in: 1.hour
    )
  end

  private

  def queue_ms_since(enqueued_at)
    return unless enqueued_at

    [((Time.current.to_f - enqueued_at) * 1000).round, 0].max
  end

  def extra_user_input_allowed?(user)
    user.confirmed_at.present? && user.confirmed_at < 2.weeks.ago &&
      (user.collected_inks.count > 20 || user.collected_pens.count > 20)
  end
end
