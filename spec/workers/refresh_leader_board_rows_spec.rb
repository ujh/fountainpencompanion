require "rails_helper"

describe RefreshLeaderBoardRows do
  it "schedules a job for each user" do
    users = create_list(:user, 2)
    expect do described_class.new.perform end.to change {
      RefreshLeaderBoardRowsForUser.jobs.length
    }.by(2)
  end
end
