class RequestPenAndInkSuggestion
  def initialize(user:, suggestion_id: nil, extra_user_input: nil)
    self.suggestion_id = suggestion_id
    self.user = user

    self.extra_user_input = extra_user_input
  end

  def perform
    if suggestion_id
      suggestion = Rails.cache.read(suggestion_id)
      return {} unless suggestion

      suggestion[:ink] = user.collected_inks.find_by(id: suggestion[:ink])
      suggestion[:pen] = user.collected_pens.find_by(id: suggestion[:pen])
      suggestion[:message] = Slodown::Formatter.new(suggestion[:message]).markdown.to_s.html_safe
      suggestion
    else
      new_suggestion_id = generate_suggestion_id
      SchedulePenAndInkSuggestion.perform_async(user.id, new_suggestion_id, extra_user_input)
      { suggestion_id: new_suggestion_id }
    end
  end

  private

  attr_accessor :suggestion_id, :user, :extra_user_input

  def generate_suggestion_id
    prefix = self.class.name.underscore.dasherize
    unique_id = SecureRandom.base58
    [prefix, unique_id].join("-")
  end
end
