require "rails_helper"

describe MacroClusterPopularity do
  describe ".refresh" do
    it "counts the public collected inks per macro cluster" do
      macro_cluster = create(:macro_cluster)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
      create_list(:collected_ink, 2, micro_cluster: micro_cluster)
      create(:collected_ink, micro_cluster: micro_cluster, private: true)
      create(:collected_ink, micro_cluster: create(:micro_cluster))

      described_class.refresh

      expect(described_class.pluck(:macro_cluster_id, :public_collected_inks_count)).to eq(
        [[macro_cluster.id, 2]]
      )
      expect(macro_cluster.popularity.public_collected_inks_count).to eq(2)
    end

    it "only refreshes concurrently once the view has been populated" do
      allow(Scenic.database).to receive(:refresh_materialized_view).and_call_original
      allow(Scenic.database).to receive(:populated?).and_return(false, true)

      2.times { described_class.refresh }

      expect(Scenic.database).to have_received(:refresh_materialized_view).with(
        "macro_cluster_popularities",
        concurrently: false,
        cascade: false
      ).ordered
      expect(Scenic.database).to have_received(:refresh_materialized_view).with(
        "macro_cluster_popularities",
        concurrently: true,
        cascade: false
      ).ordered
    end

    it "is read-only" do
      described_class.refresh

      expect(described_class.new).to be_readonly
    end
  end
end
