require "rails_helper"

describe RefreshLeaderBoardRowsForUser do
  it "properly calculates the brands leaderboard value" do
    user = create(:user)
    create(:collected_ink, user: user, brand_name: "brand 1")
    create(:collected_ink, user: user, brand_name: "brand 2")
    # same brand as previous entry
    create(:collected_ink, user: user, brand_name: "brand 2")
    # archived entry
    create(:collected_ink, user: user, brand_name: "brand 3", archived_on: Date.today)
    # private entry
    create(:collected_ink, user: user, brand_name: "brand 4", private: true)

    described_class.new.perform(user.id)

    leader_board_row = LeaderBoardRow::Brands.find_by(user: user)

    expect(leader_board_row.value).to eq(2)
  end
end
