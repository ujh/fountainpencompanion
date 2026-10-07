require "rails_helper"

describe "per-user time zone" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "still serves requests when the stored time zone is invalid" do
    user.update_column(:time_zone, "Not/AZone")

    get "/account"

    expect(response).to have_http_status(:ok)
  end
end
