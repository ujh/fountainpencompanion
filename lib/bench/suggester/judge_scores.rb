module Bench
  module Suggester
    class JudgeScores
      HONOURED = %w[yes partial no].freeze
      SCORES = %w[rationale soft_wishes concise notes_accurate].freeze

      class Invalid < StandardError
      end

      attr_accessor :grades, :key

      def initialize(grades:, key:)
        self.grades = grades
        self.key = key
      end

      def by_system
        entries
          .group_by(&:first)
          .sort
          .to_h
          .transform_values { |pairs| summarise(pairs.map(&:last)) }
      end

      private

      def entries
        grades.flat_map do |case_id, letters|
          systems = key.fetch(case_id) { raise Invalid, "case #{case_id} is not in the key" }
          letters.filter_map do |letter, grade|
            system =
              systems.fetch(letter) { raise Invalid, "case #{case_id} has no answer #{letter}" }
            [system, validate(grade, "#{case_id}/#{letter}")] if graded?(grade)
          end
        end
      end

      def graded?(grade)
        grade.values_at("honoured", *SCORES).any?(&:present?)
      end

      def validate(grade, context)
        unless HONOURED.include?(grade["honoured"])
          raise Invalid, "#{context}: honoured must be one of #{HONOURED.join(", ")}"
        end

        SCORES.each do |score|
          value = grade[score]
          unless value.is_a?(Integer) && value.between?(1, 5)
            raise Invalid, "#{context}: #{score} must be 1-5"
          end
        end
        grade
      end

      def summarise(grades)
        {
          "graded" => grades.size,
          "honoured" =>
            HONOURED.index_with { |value| grades.count { |grade| grade["honoured"] == value } },
          "honoured_yes_rate" =>
            (grades.count { |grade| grade["honoured"] == "yes" } / grades.size.to_f).round(4)
        }.merge(
          SCORES.index_with do |score|
            (grades.sum { |grade| grade[score] } / grades.size.to_f).round(2)
          end
        )
      end
    end
  end
end
