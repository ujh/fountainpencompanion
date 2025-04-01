require "rails_helper"

describe UpdateMacroCluster do
  let(:macro_cluster) { create(:macro_cluster) }
  let(:micro_cluster) { create(:micro_cluster, macro_cluster: macro_cluster) }
  let(:collected_ink1) { create(:collected_ink, micro_cluster: micro_cluster) }
  let(:collected_ink2) { create(:collected_ink, micro_cluster: micro_cluster) }
  let(:collected_ink3) { create(:collected_ink, micro_cluster: micro_cluster) }

  it "sets the color of the cluster to the average of all colors" do
    collected_ink1.update(color: "#111111")
    collected_ink2.update(color: "#333333")
    described_class.new.perform(macro_cluster.id)
    expect(macro_cluster.reload.color).to eq("#262626")
  end

  it "sets cluster_color of all collected inks" do
    collected_ink1.update(color: "#111111")
    collected_ink2.update(color: "#333333")
    described_class.new.perform(macro_cluster.id)
    expect(collected_ink1.reload.cluster_color).to eq("#262626")
    expect(collected_ink2.reload.cluster_color).to eq("#262626")
  end

  it "schedules CheckBrandClusters" do
    collected_ink1
    expect do described_class.new.perform(macro_cluster.id) end.to change {
      CheckBrandClusters.jobs.size
    }.by(1)
  end

  it "does nothing if no collected inks in cluster" do
    expect { described_class.new.perform(macro_cluster.id) }.to_not(
      change { CheckBrandClusters.jobs.size }
    )
  end

  it "sets brand_name to the most popular one" do
    collected_ink1.update(brand_name: "brand 1")
    collected_ink2.update(brand_name: "brand 1")
    collected_ink3.update(brand_name: "brand 2")
    expect do described_class.new.perform(macro_cluster.id) end.to change {
      macro_cluster.reload.brand_name
    }.to("brand 1")
  end

  it "sets line_name to the most popular one" do
    collected_ink1.update(line_name: "line 1")
    collected_ink2.update(line_name: "line 1")
    collected_ink3.update(line_name: "line 2")
    expect do described_class.new.perform(macro_cluster.id) end.to change {
      macro_cluster.reload.line_name
    }.to("line 1")
  end

  it "sets ink_name to the most popular one" do
    collected_ink1.update(ink_name: "ink 1")
    collected_ink2.update(ink_name: "ink 1")
    collected_ink3.update(ink_name: "ink 2")
    expect do described_class.new.perform(macro_cluster.id) end.to change {
      macro_cluster.reload.ink_name
    }.to("ink 1")
  end

  it "creates the embedding if it is missing" do
    collected_ink1.update(
      brand_name: "Diamine",
      line_name: "160th Anniversary",
      ink_name: "Canal Side"
    )
    expect do described_class.new.perform(macro_cluster.id) end.to change { InkEmbedding.count }.by(
      1
    )
    embedding = macro_cluster.ink_embedding
    expect(embedding.content).to eq("Diamine 160th Anniversary Canal Side")
  end

  it "updates an existing embedding" do
    collected_ink1.update(
      brand_name: "Diamine",
      line_name: "160th Anniversary",
      ink_name: "Canal Side"
    )
    embedding = macro_cluster.create_ink_embedding(content: "wrong")

    expect do
      expect { described_class.new.perform(macro_cluster.id) }.not_to(change { InkEmbedding.count })
    end.to change { embedding.reload.content }.from("wrong").to(
      "Diamine 160th Anniversary Canal Side"
    )
  end
end
