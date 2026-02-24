require "rails_helper"

describe AssignMicroCluster do
  let(:collected_ink) do
    create(
      :collected_ink,
      brand_name: "Diamine",
      line_name: "160th Anniversary",
      ink_name: "Canal Side"
    )
  end

  context "new ink" do
    it "creates a new cluster and assigns it if no matching one exists" do
      expect do subject.perform(collected_ink.id) end.to change { MicroCluster.count }.by(1)
      cluster = MicroCluster.last
      expect(collected_ink.reload.micro_cluster).to eq(cluster)
      expect(cluster.macro_cluster).to eq(nil)
    end

    it "creates the embedding" do
      expect do subject.perform(collected_ink.id) end.to change { InkEmbedding.count }.by(1)
      embedding = MicroCluster.last.ink_embedding
      expect(embedding.content).to eq("diamine 160thanniversary canalside")
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
      expect { subject.perform(collected_ink.id) }.to_not(change { MicroCluster.count })
      expect(collected_ink.reload.micro_cluster).to eq(cluster)
    end

    it "adds the embedding if it does not exist" do
      expect do subject.perform(collected_ink.id) end.to change { InkEmbedding.count }.by(1)
      embedding = cluster.ink_embedding
      expect(embedding.content).to eq("diamine 160thanniversary canalside")
    end

    it "updates an existing embedding" do
      embedding = cluster.create_ink_embedding(content: "wrong")

      expect { subject.perform(collected_ink.id) }.not_to(change { InkEmbedding.count })
      expect(embedding.reload.content).to eq("diamine 160thanniversary canalside")
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
  end

  it "uses the macro cluster id if supplied" do
    macro_cluster = create(:macro_cluster)
    expect do subject.perform(collected_ink.id, macro_cluster.id) end.to change {
      MicroCluster.count
    }.by(1)
    cluster = MicroCluster.last
    expect(cluster.macro_cluster).to eq(macro_cluster)
  end

  context "existing cluster without macro cluster" do
    let!(:cluster) do
      create(
        :micro_cluster,
        simplified_brand_name: collected_ink.simplified_brand_name,
        simplified_line_name: collected_ink.simplified_line_name,
        simplified_ink_name: collected_ink.simplified_ink_name
      )
    end

    it "sets macro_cluster_id on existing cluster when supplied and not present" do
      macro_cluster = create(:macro_cluster)
      expect { subject.perform(collected_ink.id, macro_cluster.id) }.not_to(
        change { MicroCluster.count }
      )
      expect(cluster.reload.macro_cluster).to eq(macro_cluster)
    end

    it "does not set macro_cluster_id when not supplied" do
      subject.perform(collected_ink.id)
      expect(cluster.reload.macro_cluster).to be_nil
    end
  end

  context "existing cluster with macro cluster" do
    let(:existing_macro_cluster) { create(:macro_cluster) }
    let!(:cluster) do
      create(
        :micro_cluster,
        simplified_brand_name: collected_ink.simplified_brand_name,
        simplified_line_name: collected_ink.simplified_line_name,
        simplified_ink_name: collected_ink.simplified_ink_name,
        macro_cluster: existing_macro_cluster
      )
    end

    it "does not overwrite existing macro_cluster_id" do
      new_macro_cluster = create(:macro_cluster)
      subject.perform(collected_ink.id, new_macro_cluster.id)
      expect(cluster.reload.macro_cluster).to eq(existing_macro_cluster)
    end
  end
end
