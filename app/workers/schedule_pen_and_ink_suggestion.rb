class SchedulePenAndInkSuggestion
  include Sidekiq::Worker

  def perform(user_id, suggestion_id, ink_kind)
    Rails.cache.write(
      suggestion_id,
      PenAndInkSuggester.new(User.find(user_id), ink_kind).perform,
      expires_in: 1.hour
    )
  end
end
