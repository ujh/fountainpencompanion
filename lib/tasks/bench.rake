namespace :bench do
  namespace :suggester do
    task setup: :environment do
      require Rails.root.join("lib/bench/suggester").to_s
    end

    desc "Export PenAndInkSuggester replay cases from agent logs into the bench directory"
    task export: :setup do
      extra_ids = ENV.fetch("EXTRA_LOG_IDS", "").split(",").map { |id| Integer(id) }
      exporter =
        Bench::Suggester::CaseExporter.new(
          since: Bench::Suggester.parse_since(ENV["SINCE"], default: Bench::Suggester::SINCE),
          instruction_cases: Integer(ENV.fetch("INSTRUCTION_CASES", "200")),
          plain_cases: Integer(ENV.fetch("PLAIN_CASES", "50")),
          per_user_cap: Integer(ENV.fetch("PER_USER_CAP", "20")),
          seed: Integer(ENV.fetch("SEED", "1")),
          regression_log_ids: Bench::Suggester::CaseExporter::REGRESSION_LOG_IDS + extra_ids
        )
      export = exporter.export
      Bench::Suggester::Store.new.write_export(export)
      puts "cases by source and split: #{export.cases.map { |c| [c.source, c.split] }.tally}"
      puts "users: #{export.cases.map(&:user_id).uniq.size}"
      puts "dropped by reason: #{export.dropped.transform_values(&:size)}"
    end

    desc "Write the outcome-free case files labellers read into the bench labelling directory"
    task labelling_export: :setup do
      store = Bench::Suggester::Store.new
      sheet = Bench::Suggester::LabellingSheet.new(cases: store.cases)
      store.write_labelling(sheet)
      puts "wrote #{sheet.documents.size} of #{store.cases.size} cases to " \
             "#{store.path(Bench::Suggester::LabellingSheet::DIRECTORY)}"
    end

    desc "Check a drafted label file against the schema and the exported cases (FILE=)"
    task validate_labels: :setup do
      store = Bench::Suggester::Store.new
      path = ENV.fetch("FILE") { store.path("labels.yml").to_s }
      errors = Bench::Suggester::LabelValidator.new(cases: store.cases).errors(path)
      abort errors.join("\n") if errors.any?

      puts "#{path}: ok"
    end

    desc "Add blank label entries for exported cases that have no label yet"
    task label_template: :setup do
      store = Bench::Suggester::Store.new
      added = store.write_label_template(store.cases)
      puts "added #{added} blank labels to #{store.path("labels.yml")}"
    end

    desc "Replay the cases through the current suggester " \
           "(RUN=baseline LIMIT= SPLIT= INSTRUCTION=with|without TIER=free|premium LEGACY= " \
           "MAX_USD=5 SEED=1)"
    task baseline: :setup do
      abort "The bench replays only against the development database." unless Rails.env.development?

      store = Bench::Suggester::Store.new
      name = ENV.fetch("RUN", "baseline")
      seed = Integer(ENV.fetch("SEED", "1"))
      max_usd = Float(ENV.fetch("MAX_USD", "5"))
      tier = ENV["TIER"].presence
      abort "TIER must be free or premium." if tier && %w[free premium].exclude?(tier)
      cases =
        Bench::Suggester.filter_cases(
          store.cases,
          split: ENV["SPLIT"],
          instruction: ENV["INSTRUCTION"]
        )
      cases = cases.first(Integer(ENV["LIMIT"])) if ENV["LIMIT"]

      legacy = ENV["LEGACY"].present?
      build = legacy ? Bench::Suggester::Runner::LEGACY : Bench::Suggester::Runner::BASELINE
      runner = Bench::Suggester::Runner.new(cases:, seed:, max_usd:, tier:, build:)
      results = runner.run { print "." }
      puts
      store.write_results(
        name,
        {
          "name" => name,
          "seed" => seed,
          "tier" => tier,
          "split" => ENV["SPLIT"],
          "instruction" => ENV["INSTRUCTION"],
          "legacy" => legacy,
          "max_usd" => max_usd,
          "spent_usd" => runner.spent_usd.round(4),
          "stop_reason" => runner.stop_reason,
          "results" => results
        }
      )
      puts "ran #{results.size} of #{cases.size} cases for $#{runner.spent_usd.round(4)}"
      if runner.stop_reason == Bench::Suggester::Runner::UNPRICED
        abort "stopped: a run used a model without a price in Bench::Suggester::Pricing"
      end
      puts "stopped: the MAX_USD budget is spent" if runner.stop_reason
    end

    desc "Score a recorded run with the checkers (RUN=baseline INSTRUCTION=with|without)"
    task report: :setup do
      store = Bench::Suggester::Store.new
      name = ENV.fetch("RUN", "baseline")
      report =
        Bench::Suggester::Report.new(
          cases: Bench::Suggester.filter_cases(store.cases, instruction: ENV["INSTRUCTION"]),
          results: store.results(name).fetch("results"),
          labels: store.labels
        )
      store.write_checks(name, report.rows)
      puts report.to_text
    end

    desc "Write a blinded side-by-side grading file for Claude Code " \
           "(RUNS=baseline,v2 SPLIT= INSTRUCTION=with|without)"
    task grading_export: :setup do
      store = Bench::Suggester::Store.new
      names = ENV.fetch("RUNS", "baseline").split(",")
      cases =
        Bench::Suggester.filter_cases(
          store.cases,
          split: ENV["SPLIT"],
          instruction: ENV["INSTRUCTION"]
        )
      runs = names.index_with { |name| store.results(name).fetch("results") }
      export =
        Bench::Suggester::GradingExport.new(
          cases:,
          runs:,
          labels: store.labels,
          seed: Integer(ENV.fetch("SEED", "1"))
        )
      store.write_grading(names, export)
      puts "wrote #{export.key.size} cases to #{store.path(store.grading_directory(names))}"
    end

    desc "Summarise filled-in grades and the instruction-honoured rate (RUNS=baseline,v2)"
    task judge_scores: :setup do
      store = Bench::Suggester::Store.new
      names = ENV.fetch("RUNS", "baseline").split(",")
      scores =
        Bench::Suggester::JudgeScores.new(
          grades: store.grades(names),
          key: store.grading_key(names)
        )
      honoured =
        Bench::Suggester::InstructionHonoured.new(
          judge_scores: scores,
          checks: names.index_with { |name| store.checks(name) }
        )
      puts JSON.pretty_generate(
             "judge" => scores.by_system,
             "instruction_honoured" => honoured.by_system
           )
    end

    desc "Run the label-free checkers on live suggester logs (SINCE=2026-10-01)"
    task check_logs: :setup do
      since = Bench::Suggester.parse_since(ENV["SINCE"], default: 4.weeks.ago.beginning_of_day)
      logs =
        AgentLog
          .where(name: PenAndInkSuggester.name, owner_type: User.name)
          .where(created_at: since..)
          .includes(:agent_logs)
          .order(:id)
      puts Bench::Suggester::Report.for_logs(logs).to_text
    end
  end
end
