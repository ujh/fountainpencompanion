require_relative "bench_helper"

RSpec.describe Bench::Clusterer::Store do
  let(:dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(dir) }

  subject(:store) { described_class.new(dir) }

  it "defaults to a directory under tmp, which git ignores" do
    expect(Bench::Clusterer.default_root).to eq(Rails.root.join("tmp/bench/clusterer").to_s)
    expect(File.read(Rails.root.join(".gitignore"))).to include("/tmp/*")
  end

  it "writes and reads the cases" do
    store.write_cases([bench_case])

    expect(store.cases).to eq([bench_case])
  end

  it "writes and reads the results of a run" do
    store.write_results("current", [{ "case_id" => "assign-1", "run" => 0, "got" => "approve" }])

    expect(store.results("current")).to eq(
      [{ "case_id" => "assign-1", "run" => 0, "got" => "approve" }]
    )
  end

  it "rejects run names that are not plain file names" do
    expect { store.write_results("../cases", []) }.to raise_error(described_class::InvalidRunName)
  end
end
