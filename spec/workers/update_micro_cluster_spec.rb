require "rails_helper"

describe UpdateMicroCluster do
  let(:ignored_brand) { described_class::IGNORED_BRANDS.first }

  it "updates the macro cluster when the micro cluster is assigned" do
    macro_cluster = create(:macro_cluster)
    micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
    Sidekiq::Worker.clear_all

    described_class.new.perform(micro_cluster.id)

    expect(UpdateMacroCluster.jobs.map { |job| job["args"] }).to eq([[macro_cluster.id]])
    expect(RunInkClustererAgent.jobs).to be_empty
  end

  it "runs the clusterer for an unassigned micro cluster" do
    micro_cluster = create(:micro_cluster)

    described_class.new.perform(micro_cluster.id)

    expect(RunInkClustererAgent.jobs.map { |job| job["args"] }).to eq(
      [["InkClusterer", micro_cluster.id]]
    )
    expect(micro_cluster.reload).not_to be_ignored
  end

  it "does nothing for an already ignored micro cluster" do
    micro_cluster = create(:micro_cluster, ignored: true)

    described_class.new.perform(micro_cluster.id)

    expect(RunInkClustererAgent.jobs).to be_empty
    expect(UpdateMacroCluster.jobs).to be_empty
  end

  context "with a micro cluster of an ignored brand" do
    it "ignores the micro cluster instead of running the clusterer" do
      micro_cluster = create(:micro_cluster, simplified_brand_name: ignored_brand)

      described_class.new.perform(micro_cluster.id)

      expect(micro_cluster.reload).to be_ignored
      expect(RunInkClustererAgent.jobs).to be_empty
    end

    it "ignores it again after an admin has unignored it" do
      micro_cluster = create(:micro_cluster, simplified_brand_name: ignored_brand, ignored: false)
      micro_cluster.agent_logs.create!(
        name: "InkClusterer",
        state: AgentLog::REJECTED,
        transcript: [],
        extra_data: {
          action: "ignore_ink"
        }
      )

      described_class.new.perform(micro_cluster.id)

      expect(micro_cluster.reload).to be_ignored
      expect(RunInkClustererAgent.jobs).to be_empty
    end

    it "leaves a micro cluster that is already assigned to a macro cluster alone" do
      macro_cluster = create(:macro_cluster)
      micro_cluster =
        create(:micro_cluster, simplified_brand_name: ignored_brand, macro_cluster: macro_cluster)
      Sidekiq::Worker.clear_all

      described_class.new.perform(micro_cluster.id)

      expect(micro_cluster.reload).not_to be_ignored
      expect(UpdateMacroCluster.jobs.map { |job| job["args"] }).to eq([[macro_cluster.id]])
    end
  end
end
