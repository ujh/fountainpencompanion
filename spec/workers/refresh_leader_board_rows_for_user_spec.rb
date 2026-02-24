require "rails_helper"

describe RefreshLeaderBoardRowsForUser do
  describe "brands leaderboard" do
    it "properly calculates the brands leaderboard value" do
      user = create(:user)
      brand_cluster1 = create(:brand_cluster, name: "Brand 1")
      brand_cluster2 = create(:brand_cluster, name: "Brand 2")
      brand_cluster3 = create(:brand_cluster, name: "Brand 3")
      macro_cluster1 = create(:macro_cluster, brand_cluster: brand_cluster1)
      macro_cluster2 = create(:macro_cluster, brand_cluster: brand_cluster2)
      macro_cluster3 = create(:macro_cluster, brand_cluster: brand_cluster3)
      micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
      micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)
      micro_cluster3 = create(:micro_cluster, macro_cluster: macro_cluster3)

      create(:collected_ink, user: user, brand_name: "Brand 1", micro_cluster: micro_cluster1)
      create(:collected_ink, user: user, brand_name: "Brand 2", micro_cluster: micro_cluster2)
      # collected ink without micro_cluster should be counted via brand_name
      create(:collected_ink, user: user, brand_name: "Brand 3")
      # collected ink with micro_cluster but without macro_cluster should be counted via brand_name
      micro_cluster_no_macro = create(:micro_cluster, macro_cluster: nil)
      create(
        :collected_ink,
        user: user,
        brand_name: "Brand 3",
        micro_cluster: micro_cluster_no_macro
      )

      described_class.new.perform(user.id)

      leader_board_row = LeaderBoardRow::Brands.find_by(user: user)

      # 2 from clusters (Brand 1, Brand 2) + 1 distinct brand_name from unclustered (Brand 3)
      expect(leader_board_row.value).to eq(3)
    end

    it "counts inks with the same brand cluster as a single brand" do
      user = create(:user)
      brand_cluster = create(:brand_cluster, name: "Diamine")
      macro_cluster1 = create(:macro_cluster, brand_cluster: brand_cluster)
      macro_cluster2 = create(:macro_cluster, brand_cluster: brand_cluster)
      micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
      micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)

      create(:collected_ink, user: user, brand_name: "Diamine", micro_cluster: micro_cluster1)
      create(:collected_ink, user: user, brand_name: "Diamine", micro_cluster: micro_cluster1)
      create(:collected_ink, user: user, brand_name: "Diamine", micro_cluster: micro_cluster2)

      described_class.new.perform(user.id)

      leader_board_row = LeaderBoardRow::Brands.find_by(user: user)

      expect(leader_board_row.value).to eq(1)
    end

    it "counts distinct brand_names for unclustered inks" do
      user = create(:user)
      # No micro_cluster at all
      create(:collected_ink, user: user, brand_name: "Unclustered Brand A")
      create(:collected_ink, user: user, brand_name: "Unclustered Brand A")
      create(:collected_ink, user: user, brand_name: "Unclustered Brand B")
      # micro_cluster without macro_cluster
      micro_cluster_no_macro = create(:micro_cluster, macro_cluster: nil)
      create(
        :collected_ink,
        user: user,
        brand_name: "Unclustered Brand C",
        micro_cluster: micro_cluster_no_macro
      )

      described_class.new.perform(user.id)

      leader_board_row = LeaderBoardRow::Brands.find_by(user: user)

      # 3 distinct brand_names: "Unclustered Brand A", "Unclustered Brand B", "Unclustered Brand C"
      expect(leader_board_row.value).to eq(3)
    end

    it "combines clustered and unclustered counts" do
      user = create(:user)
      brand_cluster = create(:brand_cluster, name: "Diamine")
      macro_cluster = create(:macro_cluster, brand_cluster: brand_cluster)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)

      # 1 clustered brand
      create(:collected_ink, user: user, brand_name: "Diamine", micro_cluster: micro_cluster)
      # 2 unclustered brands
      create(:collected_ink, user: user, brand_name: "Unknown Brand X")
      create(:collected_ink, user: user, brand_name: "Unknown Brand Y")

      described_class.new.perform(user.id)

      leader_board_row = LeaderBoardRow::Brands.find_by(user: user)

      # 1 from clusters + 2 distinct brand_names from unclustered
      expect(leader_board_row.value).to eq(3)
    end

    it "does not count private unclustered inks" do
      user = create(:user)
      # Public unclustered ink should be counted
      create(:collected_ink, user: user, brand_name: "Public Brand")
      # Private unclustered ink should not be counted
      create(:collected_ink, user: user, brand_name: "Private Brand", private: true)
      # Private unclustered ink with micro_cluster but no macro_cluster should not be counted
      micro_cluster_no_macro = create(:micro_cluster, macro_cluster: nil)
      create(
        :collected_ink,
        user: user,
        brand_name: "Private Brand 2",
        micro_cluster: micro_cluster_no_macro,
        private: true
      )

      described_class.new.perform(user.id)

      leader_board_row = LeaderBoardRow::Brands.find_by(user: user)

      expect(leader_board_row.value).to eq(1)
    end
  end
end
