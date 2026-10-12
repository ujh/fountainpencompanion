module Bench
  module Suggester
    class JudgeScores
      HONOURED = %w[yes partial no].freeze
      SCORES = %w[rationale soft_wishes concise notes_accurate].freeze

      class Invalid < StandardError
      end

      attr_accessor :judges, :key

      def initialize(judges:, key:)
        self.judges = judges
        self.key = key
      end

      def by_system
        unblinded
          .group_by { |_case_id, system, _grade| system }
          .sort
          .to_h do |system, entries|
            summary = summarise(entries.map(&:last))
            summary["agreement"] = agreement(system) if judges.size > 1
            [system, summary]
          end
      end

      def unblinded
        @unblinded ||=
          per_judge
            .flat_map(&:keys)
            .uniq
            .map do |case_id, system|
              grades =
                per_judge.map do |judge|
                  judge.fetch([case_id, system]) do
                    raise Invalid, "case #{case_id} (#{system}) is not graded by every judge"
                  end
                end
              [case_id, system, combine(grades)]
            end
      end

      private

      def per_judge
        @per_judge ||= judges.map { |grades| unblind(grades) }
      end

      def unblind(grades)
        grades
          .flat_map do |case_id, letters|
            systems = key.fetch(case_id) { raise Invalid, "case #{case_id} is not in the key" }
            letters.filter_map do |letter, grade|
              system =
                systems.fetch(letter) { raise Invalid, "case #{case_id} has no answer #{letter}" }
              [[case_id, system], validate(grade, "#{case_id}/#{letter}")] if graded?(grade)
            end
          end
          .to_h
      end

      def combine(grades)
        return grades.first if grades.one?

        honoured = grades.pluck("honoured")
        combined =
          if honoured.all?("yes")
            "yes"
          elsif honoured.include?("no")
            "no"
          else
            "partial"
          end
        { "honoured" => combined }.merge(
          SCORES.index_with { |score| grades.sum { |grade| grade[score] } / grades.size.to_f }
        )
      end

      def agreement(system)
        answers =
          per_judge.map { |judge| judge.select { |(_case_id, graded), _grade| graded == system } }
        ids = answers.first.keys
        pairs =
          (1..judges.size)
            .to_a
            .combination(2)
            .to_h do |first, second|
              [
                "#{first}-#{second}",
                cohens_kappa(
                  ids.map { |id| answers[first - 1][id]["honoured"] },
                  ids.map { |id| answers[second - 1][id]["honoured"] }
                )
              ]
            end
        {
          "answers" => ids.size,
          "identical" => ids.count { |id| answers.map { |judge| judge[id]["honoured"] }.uniq.one? },
          "kappa" => pairs
        }
      end

      def cohens_kappa(first, second)
        observed = first.zip(second).count { |a, b| a == b } / first.size.to_f
        expected =
          HONOURED.sum do |value|
            (first.count(value) / first.size.to_f) * (second.count(value) / second.size.to_f)
          end
        return nil if expected == 1

        ((observed - expected) / (1 - expected)).round(2)
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
