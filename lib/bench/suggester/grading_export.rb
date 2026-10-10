module Bench
  module Suggester
    class GradingExport
      RUBRIC = <<~TEXT
        Grade each blinded answer on its own. Fill grades.json (copied from grades_template.json):

        - honoured: "yes", "partial" or "no": was the request (or, without one, the default
          behaviour of a varied, mostly novel pick) honoured?
        - rationale: 1-5, is the pairing rationale coherent with the nib and the ink?
        - soft_wishes: 1-5, mood, season, pen-colour match and other soft wishes (5 when none)
        - concise: 1-5, concise and free of rule leakage (novelty talk, headings, ids, links)
        - notes_accurate: 1-5, are server notes and claims about the items accurate?
      TEXT
      GRADE_FIELDS = %w[honoured rationale soft_wishes concise notes_accurate comment].freeze

      attr_accessor :cases, :runs, :labels, :seed

      def initialize(cases:, runs:, labels: {}, seed: 1)
        self.cases = cases
        self.runs = runs
        self.labels = labels
        self.seed = seed
      end

      def files
        {
          "grading.md" => markdown,
          "grading_key.json" => JSON.pretty_generate(key),
          "grades_template.json" => JSON.pretty_generate(template)
        }
      end

      def key
        @key ||=
          graded_cases.to_h do |bench_case|
            systems =
              runs.keys.sort.shuffle(random: Random.new(Zlib.crc32("#{seed}:#{bench_case.id}")))
            [
              bench_case.id,
              systems.each_with_index.to_h { |system, index| [letters[index], system] }
            ]
          end
      end

      private

      def graded_cases
        cases.select { |bench_case| runs.values.any? { |results| results.key?(bench_case.id) } }
      end

      def letters
        ("A".."Z").to_a
      end

      def template
        key.transform_values do |systems|
          systems.keys.index_with do
            GRADE_FIELDS.index_with { |field| field == "comment" ? "" : nil }
          end
        end
      end

      def markdown
        [
          "# Suggester grading",
          RUBRIC,
          *graded_cases.map { |bench_case| case_section(bench_case) }
        ].join("\n\n")
      end

      def case_section(bench_case)
        snapshot = snapshot_for(bench_case)
        lines = [
          "## Case #{bench_case.id} (#{bench_case.split}, #{bench_case.source}, #{bench_case.tier})",
          "",
          "Request: #{bench_case.instruction.presence || "(none)"}",
          "Rejected pairs before this run: #{bench_case.rejected_pairs.size}"
        ]
        notes = labels[bench_case.id]&.notes
        lines << "Label notes: #{notes}" if notes.present?
        key[bench_case.id].each do |letter, system|
          lines.push("", "### #{letter}", *answer_lines(runs[system][bench_case.id], snapshot))
        end
        lines.join("\n")
      end

      def answer_lines(result, snapshot)
        return ["(no result)"] unless result

        extra_data = result["extra_data"].to_h.stringify_keys
        pen = snapshot&.pens&.find { |candidate| candidate.id == extra_data["pen"] }
        ink = snapshot&.inks&.find { |candidate| candidate.id == extra_data["ink"] }
        [
          "- Pen: #{pen ? pen_description(pen, snapshot) : "(none)"}",
          "- Ink: #{ink ? ink_description(ink) : "(none)"}",
          "",
          *extra_data["message"].to_s.lines.map { |line| "> #{line.chomp}" }
        ]
      end

      def pen_description(pen, snapshot)
        nib = snapshot.nib_profile(pen).label || "nib unknown"
        filling = pen.filling_system.presence || "filling unknown"
        "#{pen.name} (#{nib}; #{filling})"
      end

      def ink_description(ink)
        details = [
          ink.kind.presence,
          ColorProfile.for(ink).label,
          *PenAndInkSuggestion::InkProperties.for(ink).labels
        ].compact
        "#{ink.name} (#{details.join("; ")})"
      end

      def snapshot_for(bench_case)
        user = User.find_by(id: bench_case.user_id)
        PenAndInkSuggestion::CollectionSnapshot.new(user, as_of: bench_case.as_of) if user
      end
    end
  end
end
