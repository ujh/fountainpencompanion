require_relative "bench_helper"

RSpec.describe Bench::Suggester::CaseExporter do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let(:pen) { create(:collected_pen, user:, created_at: as_of - 30.days) }
  let(:ink) { create(:collected_ink, user:, created_at: as_of - 30.days) }

  def exporter(**options)
    described_class.new(regression_log_ids: [], **options)
  end

  def log_for(owner = user, pens: [pen], inks: [ink], created_at: as_of, **options)
    suggester_log(
      user: owner,
      created_at:,
      pen_ids: pens.map(&:id),
      ink_ids: inks.map(&:id),
      extra_data: {
        "pen" => pens.first&.id,
        "ink" => inks.first&.id,
        "message" => "Use them"
      },
      **options
    )
  end

  describe "case contents" do
    it "builds a case from the log" do
      log = log_for(instruction: "Only samples", rejected: [{ ink_id: ink.id, pen_id: pen.id }])

      bench_case = exporter.export.cases.sole

      expect(bench_case).to have_attributes(
        id: log.id.to_s,
        log_id: log.id,
        user_id: user.id,
        source: "instruction",
        tier: "free",
        instruction: "Only samples",
        rejected_pairs: [{ "ink_id" => ink.id, "pen_id" => pen.id }],
        fidelity: {
          "pens" => 1.0,
          "inks" => 1.0
        }
      )
      expect(bench_case.as_of).to eq(log.created_at)
      expect(bench_case.original).to include("pen_id" => pen.id, "ink_id" => ink.id)
      expect(bench_case.split).to be_in(%w[dev test])
    end

    it "marks runs without an instruction as plain" do
      log_for

      expect(exporter.export.cases.sole.source).to eq("plain")
    end

    it "round-trips through a hash" do
      log_for(instruction: "Blue")
      bench_case = exporter.export.cases.sole

      expect(Bench::Suggester::BenchCase.from_h(JSON.parse(bench_case.to_h.to_json))).to eq(
        bench_case
      )
    end

    it "skips prechecks, other agents, runs before the cutoff and logs without a prompt" do
      log_for(created_at: Time.utc(2026, 3, 23))
      log_for.update!(extra_data: { "message" => "x", "precheck" => "no_uninked_pens" })
      log_for.update!(name: "SpamClassifier")
      create(:agent_log, name: "PenAndInkSuggester", owner: user, transcript: [])

      expect(exporter.export.cases).to be_empty
    end

    it "splits by user, the same way on every export" do
      users = create_list(:user, 6)
      users.each do |owner|
        pen = create(:collected_pen, user: owner, created_at: as_of - 1.day)
        ink = create(:collected_ink, user: owner, created_at: as_of - 1.day)
        2.times { log_for(owner, pens: [pen], inks: [ink]) }
      end

      splits =
        exporter(seed: 1)
          .export
          .cases
          .group_by(&:user_id)
          .transform_values { |cases| cases.map(&:split).uniq }

      expect(splits.values).to all(have_attributes(size: 1))
      expect(exporter(seed: 2).export.cases.to_h { |c| [c.user_id, c.split] }).to eq(
        splits.transform_values(&:first)
      )
    end
  end

  describe "sampling" do
    it "keeps one run per distinct (user, normalised text) pair" do
      log_for(instruction: "Not a Parker")
      log_for(instruction: "not a  parker")
      log_for(instruction: "Blue")
      other = create(:user)
      other_pen = create(:collected_pen, user: other, created_at: as_of - 1.day)
      other_ink = create(:collected_ink, user: other, created_at: as_of - 1.day)
      log_for(other, pens: [other_pen], inks: [other_ink], instruction: "Not a Parker")

      cases = exporter.export.cases

      expect(cases.map { |c| [c.user_id, c.instruction.downcase.squish] }).to contain_exactly(
        [user.id, "not a parker"],
        [user.id, "blue"],
        [other.id, "not a parker"]
      )
    end

    it "caps each user and takes users in turn" do
      heavy = (1..5).map { |n| log_for(instruction: "Request #{n}") }
      light_user = create(:user)
      light_pen = create(:collected_pen, user: light_user, created_at: as_of - 1.day)
      light_ink = create(:collected_ink, user: light_user, created_at: as_of - 1.day)
      light = log_for(light_user, pens: [light_pen], inks: [light_ink], instruction: "Only one")

      capped = exporter(per_user_cap: 2).export.cases
      limited = exporter(instruction_cases: 2).export.cases

      expect(capped.map(&:user_id).tally).to eq({ user.id => 2, light_user.id => 1 })
      expect(capped.map(&:log_id) - heavy.map(&:id)).to eq([light.id])
      expect(limited.map(&:user_id)).to contain_exactly(user.id, light_user.id)
    end

    it "samples instruction and plain runs to their own targets" do
      3.times { |n| log_for(instruction: "Request #{n}") }
      3.times { log_for }

      cases = exporter(instruction_cases: 2, plain_cases: 1).export.cases

      expect(cases.map(&:source).tally).to eq({ "instruction" => 2, "plain" => 1 })
    end

    it "is deterministic for a seed" do
      8.times { |n| log_for(instruction: "Request #{n}") }

      first = exporter(instruction_cases: 3, seed: 5).export.cases.map(&:log_id)
      again = exporter(instruction_cases: 3, seed: 5).export.cases.map(&:log_id)

      expect(again).to eq(first)
    end

    it "always includes the regression logs, outside the caps" do
      regression = log_for(instruction: "Request")
      log_for(instruction: "request")
      log_for(instruction: "Other")

      cases = exporter(regression_log_ids: [regression.id], instruction_cases: 0).export.cases

      expect(cases.map { |c| [c.log_id, c.source] }).to eq([[regression.id, "regression"]])
    end

    it "lists the plan's named regression set" do
      expect(described_class::REGRESSION_LOG_IDS).to include(59_469, 48_500, 48_526, 73_378, 52_095)
      expect(described_class::REGRESSION_LOG_IDS.size).to eq(29 + 27 + 7 + 3)
    end
  end

  describe "as_of state" do
    it "keeps a case whose items were archived after the run" do
      log_for(instruction: "Blue")
      pen.update!(archived_on: as_of.to_date + 5)
      ink.update!(archived_on: as_of.to_date + 5)

      expect(exporter.export.cases.size).to eq(1)
    end

    it "scores the fidelity against the items active at the time of the run" do
      inks = [ink] + create_list(:collected_ink, 9, user:, created_at: as_of - 1.day)
      log_for(inks:)
      inks.last.update!(archived_on: as_of.to_date - 1)

      expect(exporter.export.cases.sole.fidelity).to eq({ "pens" => 1.0, "inks" => 0.9 })
    end
  end

  describe "dropped cases" do
    it "drops and counts a case whose user was deleted" do
      log = log_for(instruction: "Blue")
      log.update!(owner_id: 0)

      export = exporter.export

      expect(export.cases).to be_empty
      expect(export.dropped).to eq({ "user_deleted" => [log.id] })
    end

    it "drops and counts a case whose suggested pen or ink is not in the state at the time" do
      deleted_pen = log_for(instruction: "Blue")
      later_ink = create(:collected_ink, user:, created_at: as_of + 1.day)
      other_pen = create(:collected_pen, user:, created_at: as_of - 1.day)
      ink_created_later = log_for(pens: [other_pen], inks: [later_ink], instruction: "Red")
      pen.destroy!

      export = exporter.export

      expect(export.cases).to be_empty
      expect(export.dropped).to eq({ "target_missing" => [deleted_pen.id, ink_created_later.id] })
    end

    it "drops and counts a case whose shown items can no longer be rebuilt" do
      pens = [pen] + create_list(:collected_pen, 3, user:, created_at: as_of - 1.day)
      log = log_for(pens:, instruction: "Blue")
      pens.last.destroy!

      export = exporter.export

      expect(export.cases).to be_empty
      expect(export.dropped).to eq({ "state_not_rebuilt" => [log.id] })
    end

    it "tries another run of the same request when the first can't be rebuilt" do
      gone = create(:collected_pen, user:, created_at: as_of - 1.day)
      broken = log_for(pens: [gone], instruction: "Blue")
      kept = log_for(instruction: "blue")
      gone.destroy!

      dropped_by_seed = (1..6).map { |seed| exporter(seed:).export.dropped }

      (1..6).each { |seed| expect(exporter(seed:).export.cases.map(&:log_id)).to eq([kept.id]) }
      expect(dropped_by_seed).to include({ "target_missing" => [broken.id] })
    end
  end
end
