require_relative "bench_helper"

RSpec.describe Bench::Clusterer::CaseExporter do
  let(:user) { create(:user) }
  let(:old_cluster) { create(:macro_cluster, created_at: 1.month.ago) }

  def micro_cluster(macro_cluster: nil, ignored: false, ink_name: "Kon-peki")
    create(:micro_cluster, macro_cluster:, ignored:).tap do |cluster|
      cluster.collected_inks = [
        create(:collected_ink, user:, brand_name: "Pilot", line_name: "Iroshizuku", ink_name:)
      ]
    end
  end

  def clusterer_log(owner, action:, follow_up: "approve", cluster_id: nil, created_at: 2.days.ago)
    AgentLog.create!(
      name: "InkClusterer",
      owner:,
      transcript: [{ "role" => "user", "content" => "cluster this" }],
      created_at:,
      extra_data: {
        "action" => action,
        "cluster_id" => cluster_id,
        "follow_up_action" => follow_up,
        "explanation_of_decision" => "Because."
      }.compact
    )
  end

  def export(per_group: 10, round1_per_group: 10, excluded: [])
    described_class
      .new(
        source: Bench::Clusterer::Source,
        since: 1.week.ago,
        before: Time.current,
        per_group:,
        round1_per_group:,
        seed: "1",
        excluded:
      )
      .export
      .cases
  end

  def checker_cases(**options)
    export(**options).reject(&:round1?)
  end

  it "grades an assignment by whether the micro cluster is in the target cluster now" do
    kept = micro_cluster(macro_cluster: old_cluster)
    moved = micro_cluster(macro_cluster: create(:macro_cluster))
    kept_log = clusterer_log(kept, action: "assign_to_cluster", cluster_id: old_cluster.id)
    moved_log = clusterer_log(moved, action: "assign_to_cluster", cluster_id: old_cluster.id)

    cases = checker_cases.index_by(&:log_id)

    expect(cases.fetch(kept_log.id)).to have_attributes(
      id: "assign-#{kept_log.id}",
      kind: "assign",
      expected: "approve",
      disputed: false,
      cluster_id: old_cluster.id,
      micro_cluster_id: kept.id,
      explanation: "Because.",
      transcript: [{ "role" => "user", "content" => "cluster this" }]
    )
    expect(cases.fetch(moved_log.id)).to have_attributes(expected: "reject", disputed: true)
  end

  it "grades an ignore by whether the micro cluster is ignored now" do
    ignored = micro_cluster(ignored: true)
    assigned = micro_cluster(macro_cluster: old_cluster)
    ignored_log = clusterer_log(ignored, action: "ignore_ink", follow_up: "reject")
    assigned_log = clusterer_log(assigned, action: "ignore_ink")

    cases = checker_cases.index_by(&:log_id)

    expect(cases.fetch(ignored_log.id)).to have_attributes(
      kind: "ignore",
      expected: "approve",
      disputed: true
    )
    expect(cases.fetch(assigned_log.id)).to have_attributes(expected: "reject", disputed: true)
  end

  it "grades a new cluster by whether the micro cluster is in a cluster created after the log" do
    created = micro_cluster(macro_cluster: create(:macro_cluster, created_at: 1.day.ago))
    joined = micro_cluster(macro_cluster: old_cluster)
    created_log = clusterer_log(created, action: "create_new_cluster")
    joined_log = clusterer_log(joined, action: "create_new_cluster")

    cases = checker_cases.index_by(&:log_id)

    expect(cases.fetch(created_log.id)).to have_attributes(kind: "create", expected: "approve")
    expect(cases.fetch(joined_log.id)).to have_attributes(expected: "reject", disputed: true)
  end

  it "exports the inks with their user" do
    cluster = micro_cluster(macro_cluster: old_cluster)
    clusterer_log(cluster, action: "assign_to_cluster", cluster_id: old_cluster.id)

    expect(checker_cases.first.inks).to eq(
      [
        {
          "brand_name" => "Pilot",
          "line_name" => "Iroshizuku",
          "ink_name" => "Kon-peki",
          "color" => cluster.collected_inks.first.color,
          "kind" => cluster.collected_inks.first.kind,
          "user_id" => user.id
        }
      ]
    )
  end

  it "leaves out undecided micro clusters, empty ones, logs outside the window and unreviewed logs" do
    clusterer_log(micro_cluster, action: "assign_to_cluster", cluster_id: old_cluster.id)
    clusterer_log(
      create(:micro_cluster, macro_cluster: old_cluster),
      action: "assign_to_cluster",
      cluster_id: old_cluster.id
    )
    clusterer_log(
      micro_cluster(macro_cluster: old_cluster),
      action: "assign_to_cluster",
      cluster_id: old_cluster.id,
      created_at: 2.weeks.ago
    )
    clusterer_log(
      micro_cluster(macro_cluster: old_cluster),
      action: "assign_to_cluster",
      cluster_id: old_cluster.id,
      follow_up: nil
    )

    expect(checker_cases).to be_empty
  end

  it "uses only the latest log of an action per micro cluster" do
    cluster = micro_cluster(macro_cluster: old_cluster)
    clusterer_log(
      cluster,
      action: "assign_to_cluster",
      cluster_id: old_cluster.id,
      created_at: 3.days.ago
    )
    latest = clusterer_log(cluster, action: "assign_to_cluster", cluster_id: old_cluster.id)

    expect(checker_cases.map(&:log_id)).to eq([latest.id])
  end

  it "limits each group of kind, expected decision and dispute" do
    3.times do
      clusterer_log(
        micro_cluster(macro_cluster: old_cluster),
        action: "assign_to_cluster",
        cluster_id: old_cluster.id
      )
    end
    clusterer_log(micro_cluster(ignored: true), action: "ignore_ink")

    expect(checker_cases(per_group: 2).map(&:kind).tally).to eq("assign" => 2, "ignore" => 1)
  end

  it "leaves out the logs and micro clusters of an excluded export" do
    excluded_log =
      clusterer_log(
        micro_cluster(macro_cluster: old_cluster),
        action: "assign_to_cluster",
        cluster_id: old_cluster.id
      )
    excluded_cluster = micro_cluster(macro_cluster: old_cluster)
    clusterer_log(excluded_cluster, action: "assign_to_cluster", cluster_id: old_cluster.id)
    kept_log = clusterer_log(micro_cluster(ignored: true), action: "ignore_ink")
    excluded = [
      bench_case(log_id: excluded_log.id, micro_cluster_id: 0),
      bench_case(log_id: nil, micro_cluster_id: excluded_cluster.id)
    ]

    cases = export(excluded:)

    expect(cases.reject(&:round1?).map(&:log_id)).to eq([kept_log.id])
    expect(cases.map(&:micro_cluster_id)).not_to include(excluded_cluster.id)
  end

  describe "round-1 cases" do
    it "expects the outcome the micro cluster has now" do
      ignored = micro_cluster(ignored: true)
      assigned = micro_cluster(macro_cluster: old_cluster)
      created = micro_cluster(macro_cluster: create(:macro_cluster, created_at: 1.day.ago))
      [ignored, assigned, created].each do |cluster|
        clusterer_log(cluster, action: "hand_over_to_human")
      end

      cases = export.select(&:round1?).index_by(&:micro_cluster_id)

      expect(cases.fetch(ignored.id)).to have_attributes(
        id: "round1-#{ignored.id}",
        expected: "ignore_ink",
        log_id: nil,
        transcript: nil
      )
      expect(cases.fetch(assigned.id)).to have_attributes(
        expected: "assign_to_cluster",
        cluster_id: old_cluster.id
      )
      expect(cases.fetch(created.id)).to have_attributes(expected: "create_new_cluster")
    end

    it "takes micro clusters whose first clusterer run is inside the window" do
      early = micro_cluster(ignored: true)
      clusterer_log(early, action: "ignore_ink", created_at: 2.weeks.ago)
      clusterer_log(early, action: "ignore_ink")
      clusterer_log(micro_cluster, action: "hand_over_to_human")

      expect(export.select(&:round1?)).to be_empty
    end

    it "limits each expected outcome" do
      3.times { clusterer_log(micro_cluster(ignored: true), action: "hand_over_to_human") }

      expect(export(round1_per_group: 2).count(&:round1?)).to eq(2)
    end
  end
end
