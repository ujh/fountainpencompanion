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
          before: Bench::Suggester.parse_since(ENV["BEFORE"], default: nil, name: "BEFORE"),
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

    desc "Export instruction cases that name one of the user's own inks, in any role, leaving " \
           "out the requests already exported to EXCLUDE_DIR (BENCH_DIR= EXCLUDE_DIR= SINCE= " \
           "BEFORE= INSTRUCTION_CASES=40 PER_USER_CAP=20 SEED=1)"
    task export_named_inks: :setup do
      store = Bench::Suggester::Store.new
      excluded = Bench::Suggester::Store.new(ENV.fetch("EXCLUDE_DIR"))
      if store.path("cases.json").expand_path == excluded.path("cases.json").expand_path
        abort "BENCH_DIR must not be EXCLUDE_DIR."
      end

      exporter =
        Bench::Suggester::CaseExporter.new(
          since: Bench::Suggester.parse_since(ENV["SINCE"], default: Bench::Suggester::SINCE),
          before: Bench::Suggester.parse_since(ENV["BEFORE"], default: nil, name: "BEFORE"),
          instruction_cases: Integer(ENV.fetch("INSTRUCTION_CASES", "40")),
          plain_cases: 0,
          per_user_cap: Integer(ENV.fetch("PER_USER_CAP", "20")),
          seed: Integer(ENV.fetch("SEED", "1")),
          regression_log_ids: [],
          exclude_requests: Bench::Suggester::CaseExporter.request_keys(excluded.cases),
          instruction_filter: Bench::Suggester::NamedInkFilter.new
        )
      export = exporter.export
      store.write_export(export)
      puts "cases by split: #{export.cases.map(&:split).tally}"
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
           "(RUN=baseline LIMIT= SPLIT= INSTRUCTION=with|without TIER=free|premium " \
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

      runner = Bench::Suggester::Runner.new(cases:, seed:, max_usd:, tier:)
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

    desc "Write a blinded side-by-side grading file for Claude Code, a stratified sample " \
           "when MAX_CASES is set (RUNS=baseline,v2 SPLIT= INSTRUCTION=with|without MAX_CASES= SEED=1)"
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
          seed: Integer(ENV.fetch("SEED", "1")),
          max_cases: ENV["MAX_CASES"].presence&.then { |value| Integer(value) }
        )
      store.write_grading(names, export)
      puts "wrote #{export.key.size} cases to #{store.path(store.grading_directory(names))}"
      export.strata.each do |name, counts|
        puts "  #{name}: #{counts["graded"]} of #{counts["cases"]}"
      end
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

    desc "Measure the MentionMatcher false-pin rate on the labelled instruction cases"
    task mention_pins: :setup do
      store = Bench::Suggester::Store.new
      pins = Bench::Suggester::MentionPins.new(cases: store.cases, labels: store.labels)
      store.write_results("mention-pins", { "summary" => pins.summary, "rows" => pins.rows })
      puts JSON.pretty_generate(pins.summary)
    end

    desc "Write the extractor labelled set from the case labels and the supplement file, " \
           "with the user and time of the first logged run of each supplement string"
    task extractor_labels: :setup do
      store = Bench::Suggester::Store.new
      runs =
        AgentLog
          .where(name: PenAndInkSuggester.name, owner_type: User.name)
          .find_each
          .lazy
          .map { |agent_log| Bench::Suggester::LoggedRun.new(agent_log) }
      labels =
        Bench::Suggester::ExtractorLabelContext.new(runs:).call(
          Bench::Suggester::ExtractorLabel.from_cases(store.cases, store.labels) +
            store.extractor_supplement
        )
      store.write_extractor_labels(labels)
      store.extractor_labels
      puts "wrote #{labels.size} extractor labels: #{labels.map(&:source).tally}, " \
             "#{labels.count(&:context?)} with a collection"
    end

    desc "Run the constraint extractor on the labelled set and score it " \
           "(RUN=extractor SPLIT= SOURCE= LIMIT= MODEL= REASONING_EFFORT= MAX_USD=5 NAMES_FOUND=off)"
    task extractor: :setup do
      abort "The bench runs only against the development database." unless Rails.env.development?

      store = Bench::Suggester::Store.new
      name = ENV.fetch("RUN", "extractor")
      labels = store.extractor_labels
      labels = labels.select { |label| label.split == ENV["SPLIT"] } if ENV["SPLIT"].present?
      labels = labels.select { |label| label.source == ENV["SOURCE"] } if ENV["SOURCE"].present?
      labels = labels.first(Integer(ENV["LIMIT"])) if ENV["LIMIT"]
      runner =
        Bench::Suggester::ExtractorRunner.new(
          labels:,
          max_usd: Float(ENV.fetch("MAX_USD", "5")),
          model: ENV["MODEL"].presence,
          reasoning_effort: ENV["REASONING_EFFORT"].presence,
          names_found: ENV["NAMES_FOUND"] != "off"
        )
      results = runner.run { print "." }
      puts
      store.write_results(
        name,
        {
          "name" => name,
          "params_mode" => PenAndInkConstraintExtractor.params_mode,
          "model" => ENV["MODEL"].presence || PenAndInkConstraintExtractor::MODEL_ID,
          "reasoning_effort" => runner.model_settings&.reasoning_effort,
          "names_found" => runner.names_found,
          "spent_usd" => runner.spent_usd.round(4),
          "stop_reason" => runner.stop_reason,
          "results" => results
        }
      )
      Rake::Task["bench:suggester:extractor_report"].invoke
    end

    desc "Score a recorded extractor run against the labelled set (RUN=extractor)"
    task extractor_report: :setup do
      store = Bench::Suggester::Store.new
      name = ENV.fetch("RUN", "extractor")
      score =
        Bench::Suggester::ExtractorScore.new(
          labels: store.extractor_labels,
          predictions: store.results(name).fetch("results")
        )
      store.write_results("#{name}.score", { "summary" => score.summary, "rows" => score.rows })
      summary = score.summary
      puts JSON.pretty_generate(summary.except("fields", "by_split", "reviewed"))
      puts JSON.pretty_generate(
             summary["by_split"].transform_values { |split| split.except("fields") }
           )
      summary["fields"].each do |path, field|
        puts format(
               "%-28s tp %3d fp %3d fn %3d precision %s recall %s",
               path,
               field["tp"],
               field["fp"],
               field["fn"],
               field["precision"].inspect,
               field["recall"].inspect
             )
      end
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
