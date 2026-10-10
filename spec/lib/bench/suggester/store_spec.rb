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

  it "writes and reads results by run name" do
    store.write_results("baseline-1", { "results" => {} })

    expect(store.results("baseline-1")).to eq({ "results" => {} })
    expect { store.write_results("../escape", {}) }.to raise_error(described_class::InvalidRunName)
  end
end
