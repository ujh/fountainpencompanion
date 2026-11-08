module Bench
  module Clusterer
    class Report
      UNSCORED = %w[error skipped].freeze

      attr_accessor :cases, :runs

      def initialize(cases:, runs:)
        self.cases = cases
        self.runs = runs
      end

      def groups
        cases
          .group_by { |bench_case| group_name(bench_case) }
          .sort
          .to_h do |name, group_cases|
            [name, runs.transform_values { |results| score(group_cases, results) }]
          end
      end

      def changes
        return [] if runs.size < 2

        first, last = runs.values.values_at(0, -1)
        cases.filter_map do |bench_case|
          before = rate(bench_case, first)
          after = rate(bench_case, last)
          next if before.nil? || after.nil? || before == after

          {
            "case_id" => bench_case.id,
            "expected" => bench_case.expected,
            "name" => ink_name(bench_case),
            "before" => outcomes(bench_case, first),
            "after" => outcomes(bench_case, last),
            "better" => after > before
          }
        end
      end

      def to_text
        lines =
          groups.map do |name, scores|
            cells =
              scores.map { |run, s| "#{run} #{s["correct"]}/#{s["scored"]}#{unscored_note(s)}" }
            format("%-28s %s", name, cells.join("   "))
          end
        changes.each do |change|
          lines << format(
            "%-7s %-22s %-38s %s -> %s  %s",
            change["better"] ? "BETTER" : "WORSE",
            change["case_id"],
            change["expected"],
            change["before"].join(","),
            change["after"].join(","),
            change["name"]
          )
        end
        lines.join("\n")
      end

      private

      def group_name(bench_case)
        name = "#{bench_case.kind} #{bench_case.expected}"
        bench_case.disputed ? "#{name} (disputed)" : name
      end

      def score(group_cases, results)
        relevant = results_for(group_cases.map(&:id), results)
        scored = relevant.reject { |result| UNSCORED.include?(result["got"]) }
        by_id = group_cases.index_by(&:id)
        {
          "correct" => scored.count { |result| by_id.fetch(result["case_id"]).correct?(result) },
          "scored" => scored.size,
          "unscored" => relevant.size - scored.size
        }
      end

      def rate(bench_case, results)
        scored =
          results_for([bench_case.id], results).reject { |result| UNSCORED.include?(result["got"]) }
        return if scored.empty?

        scored.count { |result| bench_case.correct?(result) }.fdiv(scored.size)
      end

      def outcomes(bench_case, results)
        results_for([bench_case.id], results).map { |result| result["got"] }
      end

      def results_for(ids, results)
        results.select { |result| ids.include?(result["case_id"]) }
      end

      def unscored_note(score)
        score["unscored"].positive? ? " (+#{score["unscored"]} unscored)" : ""
      end

      def ink_name(bench_case)
        ink = bench_case.inks.first
        [ink["brand_name"], ink["line_name"], ink["ink_name"]].compact_blank.join(" | ")
      end
    end
  end
end
