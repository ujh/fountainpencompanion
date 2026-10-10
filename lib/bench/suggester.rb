module Bench
  module Suggester
    SINCE = Time.utc(2026, 3, 24)

    def self.default_root
      ENV.fetch("BENCH_DIR") { Rails.root.join("tmp/bench/suggester").to_s }
    end
  end
end

require_relative "suggester/pricing"
require_relative "suggester/constraint_schema"
require_relative "suggester/label"
require_relative "suggester/extractor_label"
require_relative "suggester/bench_case"
require_relative "suggester/logged_run"
require_relative "suggester/case_exporter"
require_relative "suggester/cartridge_compatibility"
require_relative "suggester/checks/outcome"
require_relative "suggester/checks/validity"
require_relative "suggester/checks/named_targets"
require_relative "suggester/checks/label_ids"
require_relative "suggester/checks/constraints"
require_relative "suggester/checks/rule_leakage"
require_relative "suggester/checks/novelty"
require_relative "suggester/checker"
require_relative "suggester/report"
require_relative "suggester/baseline_suggester"
require_relative "suggester/runner"
require_relative "suggester/grading_export"
require_relative "suggester/judge_scores"
require_relative "suggester/instruction_honoured"
require_relative "suggester/store"
