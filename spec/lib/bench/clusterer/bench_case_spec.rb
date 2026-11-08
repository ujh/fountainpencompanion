require_relative "bench_helper"

RSpec.describe Bench::Clusterer::BenchCase do
  it "round-trips through a hash with string keys" do
    original = bench_case

    expect(described_class.from_h(JSON.parse(original.to_h.to_json))).to eq(original)
  end

  it "maps checker kinds to the clusterer action and checker" do
    expect(bench_case(kind: "assign")).to have_attributes(
      action: "assign_to_cluster",
      checker_class: CheckInkClustering::Assign
    )
    expect(bench_case(kind: "ignore")).to have_attributes(
      action: "ignore_ink",
      checker_class: CheckInkClustering::Ignore
    )
    expect(bench_case(kind: "create")).to have_attributes(
      action: "create_new_cluster",
      checker_class: CheckInkClustering::Create
    )
  end

  it "grades a checker result by its decision" do
    expect(bench_case(expected: "reject").correct?("got" => "reject")).to be true
    expect(bench_case(expected: "reject").correct?("got" => "approve")).to be false
  end

  it "grades a round-1 assignment by its decision and its cluster" do
    round1 = bench_case(kind: "round1", expected: "assign_to_cluster", cluster_id: 7)

    expect(round1.correct?("got" => "assign_to_cluster", "cluster_id" => 7)).to be true
    expect(round1.correct?("got" => "assign_to_cluster", "cluster_id" => 8)).to be false
    expect(round1.correct?("got" => "create_new_cluster")).to be false
  end
end
