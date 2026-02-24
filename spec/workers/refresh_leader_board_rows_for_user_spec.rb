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
      # collected ink without micro_cluster should not be counted
      create(:collected_ink, user: user, brand_name: "Brand 3")
      # collected ink with micro_cluster but without macro_cluster should not be counted
      micro_cluster_no_macro = create(:micro_cluster, macro_cluster: nil)
      create(
        :collected_ink,
        user: user,
        brand_name: "Brand 3",
        micro_cluster: micro_cluster_no_macro
      )

      described_class.new.perform(user.id)

      leader_board_row = LeaderBoardRow::Brands.find_by(user: user)

      expect(leader_board_row.value).to eq(2)
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
  end
end
