module Bench
  module Suggester
    class Report
      PASSING_STATUSES = [Checks::Constraints::MET, Checks::Constraints::RELAXED].freeze

      attr_accessor :cases, :results, :labels

      def self.for_logs(agent_logs)
        runs = agent_logs.map { |agent_log| LoggedRun.new(agent_log) }
        cases =
          runs.map do |run|
            BenchCase.new(
              id: run.log_id.to_s,
              log_id: run.log_id,
              user_id: run.user_id,
              as_of: run.created_at,
              source: run.instruction.present? ? "instruction" : "plain",
              split: "online",
              tier: run.tier,
              instruction: run.instruction,
              rejected_pairs: run.rejected_pairs,
              original: run.original,
              fidelity: {
              }
            )
          end
        results =
          runs.to_h do |run|
            usages = [run.agent_log.usage, *run.agent_log.agent_logs.map(&:usage)]
            [
              run.log_id.to_s,
              {
                "extra_data" => run.extra_data,
                "usages" => usages,
                "cost_usd" => Pricing.total_cost(usages),
                "list_cost_usd" => Pricing.total_cost(usages, cache_discount: false)
              }
            ]
          end
        new(cases:, results:, labels: {})
      end

      def initialize(cases:, results:, labels: {})
        self.cases = cases
        self.results = results
        self.labels = labels
      end

      def rows
        @rows ||=
          cases.filter_map do |bench_case|
            result = results[bench_case.id]
            snapshot = snapshot_for(bench_case)
            next unless result && snapshot

            label = labels[bench_case.id]
            {
              "case_id" => bench_case.id,
              "split" => bench_case.split,
              "source" => bench_case.source,
              "label" => (label.to_h.slice("ambiguous", "reviewed", "corrected") if label),
              "checks" =>
                Checker.new(
                  snapshot:,
                  extra_data: result["extra_data"],
                  rejected_pairs: bench_case.rejected_pairs,
                  label:
                ).call,
              "cost_usd" => result["cost_usd"],
              "list_cost_usd" => result["list_cost_usd"],
              "latency_ms" => result["latency_ms"]
            }
          end
      end

      def summary_by_split
        { "all" => summary(rows) }.merge(
          rows
            .group_by { |row| row["split"] }
            .sort
            .to_h
            .transform_values { |split_rows| summary(split_rows) }
        )
      end

      def summary(rows = self.rows)
        checks = rows.map { |row| row["checks"] }
        suggestions = checks.select { |check| check["outcome"] == Checks::Outcome::SUGGESTION }
        plain = rows.select { |row| row["source"] == "plain" }.map { |row| row["checks"] }
        {
          "runs" => rows.size,
          "outcomes" => checks.map { |check| check["outcome"] }.tally.sort.to_h,
          "hard_failure_rate" => rate(checks.count { |check| check["hard_failure"] }, checks.size),
          "suggestions" => suggestions.size,
          "valid_rate" =>
            rate(suggestions.count { |check| check.dig("validity", "valid") }, suggestions.size),
          "validity_failures" => validity_failures(suggestions),
          "swab_or_cartridge_violations" =>
            suggestions.count do |check|
              check["validity"].values_at("ink_not_swab", "cartridge_compatible").include?(false)
            end,
          "rule_leakage_rate" =>
            rate(suggestions.count { |check| check.dig("leakage", "leaked") }, suggestions.size),
          "novelty" => novelty(plain),
          "cost" => cost(rows),
          "latency_ms" => latency(rows),
          "labels" => label_counts(rows),
          "label_errors" => label_errors(checks)
        }.merge(label_based(checks)).merge("reviewed_labels" => label_based(reviewed_checks(rows)))
      end

      def to_text
        summary_by_split.map { |split, values| format_summary(split, values) }.join("\n\n")
      end

      private

      def snapshot_for(bench_case)
        user = users[bench_case.user_id]
        PenAndInkSuggestion::CollectionSnapshot.new(user, as_of: bench_case.as_of) if user
      end

      def users
        @users ||= User.where(id: cases.map(&:user_id).uniq).index_by(&:id)
      end

      def rate(count, total)
        (count / total.to_f).round(4) if total.positive?
      end

      def validity_failures(suggestions)
        suggestions
          .flat_map do |check|
            check["validity"].select { |key, value| key != "valid" && value == false }.keys
          end
          .tally
          .sort
          .to_h
      end

      def novelty(plain_checks)
        suggestions =
          plain_checks.select { |check| check["outcome"] == Checks::Outcome::SUGGESTION }
        colour_known =
          suggestions.reject { |check| check.dig("novelty", "colour_new_vs_inked").nil? }
        {
          "runs" => suggestions.size,
          "ink_novel_share" =>
            rate(suggestions.count { |check| check.dig("novelty", "ink_novel") }, suggestions.size),
          "pen_novel_share" =>
            rate(suggestions.count { |check| check.dig("novelty", "pen_novel") }, suggestions.size),
          "colour_new_vs_inked_share" =>
            rate(
              colour_known.count { |check| check.dig("novelty", "colour_new_vs_inked") },
              colour_known.size
            )
        }
      end

      def label_based(checks)
        {
          "named_pen_hit" => hit_rate(checks, "pen_hit"),
          "named_ink_hit" => hit_rate(checks, "ink_hit"),
          "constraints" => constraints(checks)
        }
      end

      def reviewed_checks(rows)
        rows.select { |row| row.dig("label", "reviewed") }.map { |row| row["checks"] }
      end

      def label_errors(checks)
        unknown = checks.filter_map { |check| check["label_unknown_ids"].presence }
        {
          "cases" => unknown.size,
          "ids" => unknown.sum { |fields| fields.values.sum(&:size) },
          "fields" =>
            unknown
              .flat_map { |fields| fields.map { |field, ids| [field, ids.size] } }
              .group_by(&:first)
              .sort
              .to_h
              .transform_values { |pairs| pairs.sum(&:last) }
        }
      end

      def hit_rate(checks, key)
        values = checks.map { |check| check.dig("named", key) }.reject(&:nil?)
        { "cases" => values.size, "rate" => rate(values.count(true), values.size) }
      end

      def constraints(checks)
        labelled = checks.map { |check| check.dig("constraints", "hard") }.reject(&:blank?)
        scored =
          labelled.reject { |fields| fields.values.include?(Checks::Constraints::NO_SUGGESTION) }
        passing =
          scored.count do |fields|
            fields.values.all? { |status| PASSING_STATUSES.include?(status) }
          end
        {
          "cases" => labelled.size,
          "skipped_ambiguous" =>
            checks.count { |check| check.dig("constraints", "skipped") == Checker::AMBIGUOUS },
          "scored_cases" => scored.size,
          "met_or_relaxed_rate" => rate(passing, scored.size),
          "cases_with_unsatisfiable" =>
            scored.count { |fields| fields.values.include?(Checks::Constraints::UNSATISFIABLE) },
          "fields" =>
            labelled
              .flat_map(&:to_a)
              .group_by(&:first)
              .sort
              .to_h
              .transform_values { |pairs| pairs.map(&:last).tally.sort.to_h }
        }
      end

      def cost(rows)
        costs = rows.map { |row| row["cost_usd"] }.compact
        list_costs = rows.map { |row| row["list_cost_usd"] }.compact
        {
          "runs_priced" => costs.size,
          "total_usd" => costs.sum.round(4),
          "mean_usd" => mean(costs),
          "mean_list_usd" => mean(list_costs)
        }
      end

      def mean(values)
        (values.sum / values.size).round(5) if values.any?
      end

      def latency(rows)
        values = rows.map { |row| row["latency_ms"] }.compact.sort
        { "p50" => percentile(values, 0.5), "p90" => percentile(values, 0.9) }
      end

      def percentile(sorted, fraction)
        sorted[((sorted.size - 1) * fraction).round] if sorted.any?
      end

      def label_counts(rows)
        row_labels = rows.filter_map { |row| row["label"] }
        reviewed = row_labels.count { |label| label["reviewed"] }
        corrected = row_labels.count { |label| label["corrected"] }
        {
          "labelled" => row_labels.size,
          "ambiguous" => row_labels.count { |label| label["ambiguous"] },
          "reviewed" => reviewed,
          "corrected" => corrected,
          "draft_error_rate" => rate(corrected, reviewed)
        }
      end

      def format_summary(split, values)
        labels = values["labels"]
        label_note =
          if labels["labelled"].zero?
            "no labels: named-hit and constraint metrics are empty"
          elsif labels["reviewed"] < labels["labelled"]
            "label-based metrics are scored against unreviewed draft labels " \
              "(#{labels["reviewed"]} of #{labels["labelled"]} reviewed by the owner)"
          else
            "all #{labels["labelled"]} labels reviewed by the owner"
          end
        [
          "== #{split} (#{values["runs"]} runs; #{label_note})",
          "label-free:",
          "  outcomes: #{values["outcomes"]}",
          "  hard failures: #{percent(values["hard_failure_rate"])}",
          "  valid suggestions: #{percent(values["valid_rate"])} #{values["validity_failures"]}",
          "  swab or incompatible cartridge: #{values["swab_or_cartridge_violations"]}",
          "  rule leakage: #{percent(values["rule_leakage_rate"])}",
          "  no-instruction novelty: #{values["novelty"]}",
          "  cost: #{values["cost"]}",
          "  latency ms: #{values["latency_ms"]}",
          "label-based:",
          "  label errors (ids not in the collection at the time; fix before scoring): " \
            "#{values["label_errors"]}",
          "  drafts corrected by the owner's review: #{labels["corrected"]} of " \
            "#{labels["reviewed"]} (#{percent(labels["draft_error_rate"])})",
          "  named pen hit: #{values["named_pen_hit"]}",
          "  named ink hit: #{values["named_ink_hit"]}",
          "  hard constraints: #{values["constraints"].except("fields")}",
          "  per field: #{values["constraints"]["fields"]}",
          "label-based, owner-reviewed labels only:",
          "  named pen hit: #{values["reviewed_labels"]["named_pen_hit"]}",
          "  named ink hit: #{values["reviewed_labels"]["named_ink_hit"]}",
          "  hard constraints: #{values["reviewed_labels"]["constraints"].except("fields")}"
        ].join("\n")
      end

      def percent(value)
        value.nil? ? "n/a" : "#{(value * 100).round(1)}%"
      end
    end
  end
end
