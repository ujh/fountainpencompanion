require "rails_helper"

describe AssignMacroCluster do
  it "assigns the brand cluster that has the same name as the micro cluster" do
    mc = create(:macro_cluster, brand_name: "brand")
    brand_cluster = create(:brand_cluster, name: "brand")

    expect do described_class.new.perform(mc.id) end.to change { mc.reload.brand_cluster }.from(
      nil
    ).to(brand_cluster)
  end

  it "assigns the brand cluster via the synonyms" do
    mc = create(:macro_cluster, brand_name: "brand")
    brand_cluster = create(:brand_cluster, name: "other")
    other_mc = create(:macro_cluster, brand_name: "brand", brand_cluster: brand_cluster)

    expect do described_class.new.perform(mc.id) end.to change { mc.reload.brand_cluster }.from(
      nil
    ).to(brand_cluster)
  end

  it "gives the brand name precedence over the synonyms" do
    mc = create(:macro_cluster, brand_name: "brand")
    brand_cluster = create(:brand_cluster, name: "other")
    other_mc = create(:macro_cluster, brand_name: "brand", brand_cluster: brand_cluster)
    correct_brand_cluster = create(:brand_cluster, name: "brand")

    expect do described_class.new.perform(mc.id) end.to change { mc.reload.brand_cluster }.from(
      nil
    ).to(correct_brand_cluster)
  end

  it "does not fail if no brand cluster found" do
    mc = create(:macro_cluster, brand_name: "brand")

    described_class.new.perform(mc.id)
  end
end
