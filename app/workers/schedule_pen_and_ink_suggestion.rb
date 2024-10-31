class SchedulePenAndInkSuggestion
  include Sidekiq::Worker

  def perform(user_id, suggestion_id, ink_kind)
    Rails.cache.write(
      suggestion_id,
      Bots::PenAndInkSuggestion.new(User.find(user_id), ink_kind).run,
      expires_in: 1.hour
    )
  end
end
