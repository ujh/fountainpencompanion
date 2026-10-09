class PenAndInkSuggester
  class DailyCap
    def initialize(user)
      self.user = user
    end

    def reached?
      today_usage_count >= limit
    end

    def message
      if premium?
        "You have reached your daily limit of #{MAX_PER_DAY_PATRON} suggestions. Please try again tomorrow."
      else
        "You have reached your daily limit of #{MAX_PER_DAY} suggestions. Consider becoming a [Patron](https://www.patreon.com/bePatron?u=6900241) for a higher limit!"
      end
    end

    private

    attr_accessor :user

    def limit
      premium? ? MAX_PER_DAY_PATRON : MAX_PER_DAY
    end

    def today_usage_count
      AgentLog
        .where(name: PenAndInkSuggester.name, owner: user)
        .where("created_at >= ?", Time.current.beginning_of_day)
        .where("extra_data->'precheck' IS NULL")
        .count
    end

    def premium?
      user.patron? || user.admin?
    end
  end
end
