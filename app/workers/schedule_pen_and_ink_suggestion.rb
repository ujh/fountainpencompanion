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
    extra_user_input = nil unless PenAndInkSuggester::InstructionGate.new(user).allowed?
    result = PenAndInkSuggester.new(user, extra_user_input, rejected_suggestions, queue_ms:).perform
  ensure
    Rails.cache.write(suggestion_id, result || PenAndInkSuggester.error_result, expires_in: 1.hour)
  end

  private

  def queue_ms_since(enqueued_at)
    return unless enqueued_at

    [((Time.current.to_f - enqueued_at) * 1000).round, 0].max
  end
end
