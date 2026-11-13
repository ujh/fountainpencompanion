module ListState
  extend ActiveSupport::Concern

  KEYS = %i[q sort].freeze
  MAX_LENGTH = 200

  included { helper_method :list_state }

  private

  def list_state
    KEYS.each_with_object({}) do |key, state|
      value = params[key]
      state[key] = value.first(MAX_LENGTH) if value.is_a?(String) && value.present?
    end
  end
end
