require "rails_helper"

describe CheckBrandClusters do
  it "reassigns to the correct brand if brand_name changed" do
    old_brand_cluster = create(:brand_cluster, name: "old")
    mc =
      create(
        :macro_cluster,
        brand_name: "new",
        brand_cluster: old_brand_cluster
      )
    new_brand_cluster = create(:brand_cluster, name: "new")

    expect do described_class.new.perform(mc.id) end.to change {
      mc.reload.brand_cluster
    }.from(old_brand_cluster).to(new_brand_cluster)
  end
end
