module Bench
  module Suggester
    module Checks
      class RuleLeakage
        TERMS = /novelty|favou?rite|balance|usage count|\bid\b/i
        HEADING = /^ {0,3}\#{1,6}\s/
        LINK = %r{!?\[[^\]]*\]\([^)]*\)|https?://}i

        attr_accessor :text

        def self.for(extra_data)
          extra_data = extra_data.to_h.stringify_keys
          new(extra_data["reasoning"].presence || extra_data["message"].to_s)
        end

        def initialize(text)
          self.text = text.to_s
        end

        def call
          terms = text.scan(TERMS).map(&:downcase).uniq.sort
          headings = text.match?(HEADING)
          links = text.match?(LINK)
          {
            "terms" => terms,
            "headings" => headings,
            "links" => links,
            "leaked" => terms.any? || headings || links
          }
        end
      end
    end
  end
end
