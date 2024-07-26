class SchedulePenAndInkSuggestion
  include Sidekiq::Worker

  def perform(user_id, suggestion_id)
    Rails.cache.write(
      suggestion_id,
      Bots::PenAndInkSuggestion.new(User.find(user_id)).run,
      expires_in: 1.hour
    )
  end
end
