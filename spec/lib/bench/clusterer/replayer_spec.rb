require_relative "bench_helper"

RSpec.describe Bench::Clusterer::Replayer do
  let!(:user) { create(:user) }
  let!(:target) do
    create(:macro_cluster, brand_name: "Pilot", line_name: "Iroshizuku", ink_name: "Kon-peki")
  end

  def replay(*cases, runs: 1)
    described_class.new(cases:, runs:).run
  end

  def counts
    [MicroCluster.count, CollectedInk.count, AgentLog.count]
  end

  context "with a checker case" do
    before { stub_openai_tool_call("approve_assignment", explanation_of_decision: "Same ink.") }

    it "returns the checker's decision and the evidence it saw" do
      results = replay(bench_case(cluster_id: target.id))

      expect(results).to match(
        [
          a_hash_including(
            "case_id" => "assign-1",
            "run" => 0,
            "got" => "approve",
            "explanation" => "Same ink.",
            "evidence" => a_hash_including(ink_users: 1)
          )
        ]
      )
    end

    it "sends the round-1 explanation to the checker" do
      replay(bench_case(cluster_id: target.id, explanation: "It is the same ink."))

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |request| request.body.include?("It is the same ink.") }
    end

    it "leaves no records behind" do
      expect { replay(bench_case(cluster_id: target.id)) }.not_to(change { counts })
      expect(target.reload.micro_clusters).to be_empty
    end

    it "keeps an existing micro cluster with the same names as it was" do
      existing =
        create(
          :micro_cluster,
          simplified_brand_name: "pilot",
          simplified_line_name: "iroshizuku",
          simplified_ink_name: "konpeki",
          macro_cluster: target
        )

      results = replay(bench_case(cluster_id: target.id))

      expect(results.first["got"]).to eq("approve")
      expect(existing.reload).to have_attributes(
        simplified_ink_name: "konpeki",
        macro_cluster_id: target.id
      )
    end

    it "replays each case once per run" do
      results = replay(bench_case(cluster_id: target.id), runs: 2)

      expect(results.map { |result| result["run"] }).to eq([0, 1])
    end
  end

  it "replays a round-1 case through the clusterer" do
    stub_openai_tool_call(
      "assign_to_cluster",
      cluster_id: target.id,
      explanation_of_decision: "Same ink."
    )

    results =
      replay(
        bench_case(
          id: "round1-2",
          kind: "round1",
          log_id: nil,
          expected: "assign_to_cluster",
          cluster_id: target.id
        )
      )

    expect(results.first).to include(
      "got" => "assign_to_cluster",
      "cluster_id" => target.id,
      "explanation" => "Same ink."
    )
  end

  it "fakes Sidekiq in the threads that replay, so no job reaches Redis" do
    stub_openai_tool_call("approve_assignment", explanation_of_decision: "Same ink.")
    modes = []
    allow(CheckInkClustering::Assign).to receive(:new).and_wrap_original do |original, *args|
      modes << Sidekiq::Testing.__local_test_mode
      original.call(*args)
    end

    described_class.new(cases: [bench_case(cluster_id: target.id)], threads: 2).run

    expect(modes).to eq([:fake])
  end

  it "skips a case whose target cluster is missing from this database" do
    results = replay(bench_case(cluster_id: target.id + 1000))

    expect(results.first).to include("got" => "skipped", "error" => "target cluster missing")
    expect(WebMock).not_to have_requested(:post, "https://api.openai.com/v1/chat/completions")
  end

  it "records an error instead of stopping the replay" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(status: 500)

    expect { @results = replay(bench_case(cluster_id: target.id)) }.not_to(change { counts })
    expect(@results.first).to include("got" => "error")
    expect(@results.first["error"]).to start_with("RubyLLM::ServerError")
  end

  it "records an error when the database has fewer users than the case" do
    inks = bench_case.inks + [bench_case.inks.first.merge("user_id" => 11)]

    results = replay(bench_case(cluster_id: target.id, inks:))

    expect(results.first["error"]).to eq("ArgumentError: the database needs at least 2 users")
  end
end
