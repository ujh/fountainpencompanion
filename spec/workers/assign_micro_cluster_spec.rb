require "rails_helper"

describe AssignMicroCluster do
  let(:collected_ink) { create(:collected_ink) }

  context "new ink" do
    it "creates a new cluster and assigns it if no matching one exists" do
      expect do subject.perform(collected_ink.id) end.to change { MicroCluster.count }.by(1)
      cluster = MicroCluster.last
      expect(collected_ink.reload.micro_cluster).to eq(cluster)
      expect(cluster.macro_cluster).to eq(nil)
    end

    it "increments count of new clusters" do
      expect do subject.perform(collected_ink.id) end.to change {
        Rails.cache.read("new_cluster_count", raw: true).to_i
      }.by(1)
    end
  end

  context "existing ink" do
    let!(:cluster) do
      create(
        :micro_cluster,
        simplified_brand_name: collected_ink.simplified_brand_name,
        simplified_line_name: collected_ink.simplified_line_name,
        simplified_ink_name: collected_ink.simplified_ink_name
      )
    end

    it "reuses an existing cluster" do
      expect do subject.perform(collected_ink.id) end.to_not change { MicroCluster.count }
      expect(collected_ink.reload.micro_cluster).to eq(cluster)
    end

    it "does not send an email" do
      expect(AdminMailer).to_not receive(:new_cluster)
      expect do subject.perform(collected_ink.id) end.to_not change { MicroCluster.count }
    end
  end

  context "ink belonging to same macro cluster" do
    let!(:micro_cluster) do
      create(
        :micro_cluster,
        simplified_brand_name: collected_ink.simplified_brand_name,
        simplified_ink_name: collected_ink.simplified_ink_name,
        macro_cluster: macro_cluster
      )
    end
    let!(:macro_cluster) { create(:macro_cluster) }

    it "assigns to existing macro cluster if brand and ink are same as existing micro cluster" do
      expect do subject.perform(collected_ink.id) end.to change { MicroCluster.count }.by(1)
      cluster = MicroCluster.last
      expect(cluster.macro_cluster).to eq(macro_cluster)
    end

    it "does not send an email" do
      expect(AdminMailer).to_not receive(:new_cluster).and_call_original
      expect do subject.perform(collected_ink.id) end.to change { MicroCluster.count }.by(1)
    end
  end

  it "uses the macro cluster id if supplied" do
    macro_cluster = create(:macro_cluster)
    expect do subject.perform(collected_ink.id, macro_cluster.id) end.to change {
      MicroCluster.count
    }.by(1)
    cluster = MicroCluster.last
    expect(cluster.macro_cluster).to eq(macro_cluster)
  end
end
