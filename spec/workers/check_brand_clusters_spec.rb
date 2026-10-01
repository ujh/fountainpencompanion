require "rails_helper"

describe CheckBrandClusters do
  it "reassigns to the correct brand if brand_name changed" do
    old_brand_cluster = create(:brand_cluster, name: "old")
    mc = create(:macro_cluster, brand_name: "new", brand_cluster: old_brand_cluster)
    new_brand_cluster = create(:brand_cluster, name: "new")

    expect do described_class.new.perform(mc.id) end.to change { mc.reload.brand_cluster }.from(
      old_brand_cluster
    ).to(new_brand_cluster)
  end

  it "uses the manual brand name" do
    old_brand_cluster = create(:brand_cluster, name: "old")
    mc =
      create(
        :macro_cluster,
        brand_name: "old",
        manual_brand_name: "new",
        brand_cluster: old_brand_cluster
      )
    new_brand_cluster = create(:brand_cluster, name: "new")

    expect do described_class.new.perform(mc.id) end.to change { mc.reload.brand_cluster }.from(
      old_brand_cluster
    ).to(new_brand_cluster)
  end

  context "without ids" do
    it "only schedules clusters whose brand name differs from their brand cluster" do
      brand_cluster = create(:brand_cluster, name: "Brand")
      matching = create(:macro_cluster, brand_name: "Brand", brand_cluster: brand_cluster)
      mismatched = create(:macro_cluster, brand_name: "Other", brand_cluster: brand_cluster)
      manual_mismatched =
        create(
          :macro_cluster,
          brand_name: "Brand",
          manual_brand_name: "Other",
          brand_cluster: brand_cluster
        )
      manual_matching =
        create(
          :macro_cluster,
          brand_name: "Other",
          manual_brand_name: "Brand",
          brand_cluster: brand_cluster
        )
      unassigned = create(:macro_cluster, brand_name: "Other")

      expect { described_class.new.perform }.to change(described_class.jobs, :size).by(1)
      scheduled_ids = described_class.jobs.last["args"].first
      expect(scheduled_ids).to match_array([mismatched.id, manual_mismatched.id])
      expect(scheduled_ids).not_to include(matching.id, manual_matching.id, unassigned.id)
    end

    it "schedules clusters in groups of 50" do
      brand_cluster = create(:brand_cluster, name: "Brand")
      create_list(:macro_cluster, 51, brand_name: "Other", brand_cluster: brand_cluster)

      expect { described_class.new.perform }.to change(described_class.jobs, :size).by(2)
    end
  end
end
