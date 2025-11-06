class SchedulePenAndInkSuggestion
  include Sidekiq::Worker

  def perform(user_id, suggestion_id, extra_user_input = nil, hidden_input = nil)
    user = User.find(user_id)
    extra_user_input = nil unless extra_user_input_allowed?(user)
    Rails.cache.write(
      suggestion_id,
      PenAndInkSuggester.new(user, extra_user_input, hidden_input).perform,
      expires_in: 1.hour
    )
  end

  private

  def extra_user_input_allowed?(user)
    user.confirmed_at < 2.weeks.ago &&
      (user.collected_inks.count > 20 || user.collected_pens.count > 20)
  end
end
