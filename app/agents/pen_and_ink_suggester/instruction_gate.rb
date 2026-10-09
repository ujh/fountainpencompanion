class PenAndInkSuggester
  class InstructionGate
    MIN_ACCOUNT_AGE = 2.weeks
    MIN_ITEMS = 20

    def initialize(user)
      self.user = user
    end

    def allowed?
      established_account? &&
        (user.collected_inks.count > MIN_ITEMS || user.collected_pens.count > MIN_ITEMS)
    end

    private

    attr_accessor :user

    def established_account?
      user.confirmed_at.present? && user.confirmed_at < MIN_ACCOUNT_AGE.ago
    end
  end
end
