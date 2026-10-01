require "rails_helper"

describe RefreshAutocompletePopularities do
  it "refreshes the popularity views" do
    create(:collected_pen, brand: "Pilot")
    macro_cluster = create(:macro_cluster)
    create(:collected_ink, micro_cluster: create(:micro_cluster, macro_cluster: macro_cluster))

    described_class.new.perform

    expect(MacroClusterPopularity.pluck(:macro_cluster_id)).to eq([macro_cluster.id])
    expect(PenNamePopularity.where(field: "brand").pluck(:value)).to eq(["Pilot"])
  end
end
