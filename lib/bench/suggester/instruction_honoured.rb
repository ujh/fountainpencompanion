module Bench
  module Suggester
    class InstructionHonoured
      attr_accessor :judge_scores, :checks

      def initialize(judge_scores:, checks:)
        self.judge_scores = judge_scores
        self.checks = checks
      end

      def by_system
        entries =
          judge_scores.unblinded.filter_map do |case_id, system, grade|
            row = rows_by_system.dig(system, case_id)
            next if row && row["source"] != "instruction"

            [system, row, grade]
          end
        entries
          .group_by(&:first)
          .sort
          .to_h
          .transform_values { |system_entries| summarise(system_entries) }
      end

      private

      def rows_by_system
        @rows_by_system ||=
          checks.transform_values { |rows| rows.index_by { |row| row["case_id"] } }
      end

      def summarise(entries)
        checked = entries.select { |_system, row, _grade| row }
        scored = checked.select { |_system, row, _grade| row["label"] }
        reviewed = scored.select { |_system, row, _grade| row["label"]["reviewed"] }
        {
          "graded_without_checks" => entries.size - checked.size,
          "graded_without_label" => checked.size - scored.size,
          "all_labels" => rate(scored),
          "reviewed_labels" => rate(reviewed)
        }
      end

      def rate(entries)
        honoured = entries.count { |_system, row, grade| honoured?(row, grade) }
        {
          "cases" => entries.size,
          "honoured" => honoured,
          "rate" => entries.any? ? (honoured / entries.size.to_f).round(4) : nil
        }
      end

      def honoured?(row, grade)
        grade["honoured"] == "yes" && hard_checks_pass?(row["checks"])
      end

      def hard_checks_pass?(checks)
        !checks["hard_failure"] && checks.dig("validity", "valid") != false &&
          checks["named"].to_h.values.none?(false) &&
          checks
            .dig("constraints", "hard")
            .to_h
            .values
            .all? { |status| Report::PASSING_STATUSES.include?(status) }
      end
    end
  end
end
