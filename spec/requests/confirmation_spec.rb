require "rails_helper"

describe "GET /users/confirmation" do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, email: "old@example.com") }

  before do
    user.update!(email: "new@example.com")
    @token = user.confirmation_token
  end

  it "confirms an email change within 3 days" do
    travel 2.days
    get "/users/confirmation", params: { confirmation_token: @token }

    expect(user.reload.email).to eq("new@example.com")
  end

  it "rejects an email change confirmation older than 3 days" do
    travel 4.days
    get "/users/confirmation", params: { confirmation_token: @token }

    expect(user.reload.email).to eq("old@example.com")
  end
end
