require_relative "bench_helper"

RSpec.describe Bench::Suggester::Store do
  let(:dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(dir) }

  subject(:store) { described_class.new(dir) }

  let(:bench_case) do
    Bench::Suggester::BenchCase.new(
      id: "7",
      log_id: 7,
      user_id: 3,
      as_of: Time.zone.parse("2026-05-01 10:00:00.123456"),
      source: "plain",
      split: "dev",
      tier: "free",
      instruction: nil,
      rejected_pairs: [],
      original: {
        "pen_id" => 1
      },
      fidelity: {
        "pens" => 1.0
      }
    )
  end

  it "defaults to a directory under tmp, which git ignores" do
    expect(Bench::Suggester.default_root).to eq(Rails.root.join("tmp/bench/suggester").to_s)
    expect(File.read(Rails.root.join(".gitignore"))).to include("/tmp/*")
  end

  it "writes and reads the exported cases" do
    store.write_export(
      Bench::Suggester::CaseExporter::Export.new(
        cases: [bench_case],
        dropped: {
          "user_deleted" => [9]
        }
      )
    )

    expect(store.cases).to eq([bench_case])
    expect(store.read_json("dropped.json")).to eq("user_deleted" => [9])
  end

  it "adds blank labels for unlabelled cases and keeps existing ones" do
    File.write(
      store.path("labels.yml"),
      { "7" => { "named_pens" => [1], "reviewed" => true } }.to_yaml
    )
    other = bench_case.with(id: "8")

    added = store.write_label_template([bench_case, other])

    expect(added).to eq(1)
    expect(store.labels["7"]).to have_attributes(named_pens: [1], reviewed: true)
    expect(store.labels["8"]).to have_attributes(named_pens: [], reviewed: false, constraints: {})
  end

  it "writes the labelling sheet to its own directory, apart from the cases with outcomes" do
    sheet = instance_double(Bench::Suggester::LabellingSheet, files: { "cases/7.json" => "{}" })

    store.write_labelling(sheet)

    expect(File.read(File.join(dir, "labelling/cases/7.json"))).to eq("{}")
  end

  it "writes and reads results by run name" do
    store.write_results("baseline-1", { "results" => {} })

    expect(store.results("baseline-1")).to eq({ "results" => {} })
    expect { store.write_results("../escape", {}) }.to raise_error(described_class::InvalidRunName)
  end

  it "writes and reads the checked rows of a run" do
    store.write_checks("baseline", [{ "case_id" => "7" }])

    expect(store.checks("baseline")).to eq([{ "case_id" => "7" }])
  end

  it "keeps the grading key out of the directory handed to the judge" do
    export =
      instance_double(
        Bench::Suggester::GradingExport,
        files: {
          "grading.md" => "# Grading",
          "grades_template.json" => "{}"
        },
        key_json: JSON.generate("7" => { "A" => "v2" })
      )

    store.write_grading(%w[baseline v2], export)
    File.write(store.path("grading/baseline-vs-v2/grades.json"), "{}")

    expect(Dir.children(store.path("grading/baseline-vs-v2")).sort).to eq(
      %w[grades.json grades_template.json grading.md]
    )
    expect(store.grading_key(%w[baseline v2])).to eq("7" => { "A" => "v2" })
    expect(store.grades(%w[baseline v2])).to eq({})
    expect { store.write_grading(["../x"], export) }.to raise_error(described_class::InvalidRunName)
  end
end
