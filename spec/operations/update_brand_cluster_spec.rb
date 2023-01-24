require "rails_helper"

describe UpdateBrandCluster do
  let(:brand_cluster) { create(:brand_cluster) }
  let(:old_brand_cluster) { create(:brand_cluster) }
  let(:macro_cluster) do
    create(:macro_cluster, brand_cluster: old_brand_cluster)
  end

  it "updates the brand_cluster of the macro cluster" do
    expect do
      described_class.new(macro_cluster, brand_cluster).perform
    end.to change { macro_cluster.reload.brand_cluster }.from(
      old_brand_cluster
    ).to(brand_cluster)
  end

  it "updates other macro clusters with the same brand name" do
    second_macro_cluster =
      create(:macro_cluster, brand_name: macro_cluster.brand_name)

    expect do
      described_class.new(macro_cluster, brand_cluster).perform
    end.to change { second_macro_cluster.reload.brand_cluster }.to(
      brand_cluster
    )
  end

  it "changes the name of the brand cluster to the majority name" do
    macro_cluster.update!(brand_name: "Diamine")
    create(:macro_cluster, brand_name: "Diamine")

    expect do
      described_class.new(macro_cluster, brand_cluster).perform
    end.to change { brand_cluster.reload.name }.to("Diamine")
  end
end
