class RequestPenAndInkSuggestion
  def initialize(user:, suggestion_id: nil, extra_user_input: nil, rejected_suggestions: [])
    self.suggestion_id = suggestion_id
    self.user = user

    self.extra_user_input = extra_user_input
    self.rejected_suggestions = rejected_suggestions || []
  end

  def perform
    suggestion_id ? read_suggestion : request_suggestion
  end

  private

  attr_accessor :suggestion_id, :user, :extra_user_input, :rejected_suggestions

  def read_suggestion
    suggestion = Rails.cache.read(suggestion_id)
    return {} unless suggestion

    suggestion[:ink] = user.collected_inks.find_by(id: suggestion[:ink])
    suggestion[:pen] = user.collected_pens.find_by(id: suggestion[:pen])
    resolve_currently_inked(suggestion) if suggestion[:pen_currently_inked]
    suggestion[:message] = FpcFormatter.render(suggestion[:message]) if suggestion[:message]
    suggestion
  end

  def resolve_currently_inked(suggestion)
    inking =
      user.currently_inkeds.active.find_by(
        id: suggestion[:currently_inked_id],
        collected_pen: suggestion[:pen]
      )
    suggestion[:pen_currently_inked] = inking.present?
    suggestion[:currently_inked_id] = inking&.id
  end

  def request_suggestion
    new_suggestion_id = generate_suggestion_id
    daily_cap = PenAndInkSuggester::DailyCap.new(user)
    if daily_cap.reached?
      Rails.cache.write(new_suggestion_id, { message: daily_cap.message }, expires_in: 1.hour)
    else
      SchedulePenAndInkSuggestion.perform_async(
        user.id,
        new_suggestion_id,
        extra_user_input,
        rejected_suggestions,
        Time.current.to_f
      )
    end
    { suggestion_id: new_suggestion_id }
  end

  def generate_suggestion_id
    prefix = self.class.name.underscore.dasherize
    unique_id = SecureRandom.base58
    [prefix, unique_id].join("-")
  end
end
