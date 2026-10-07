require "rails_helper"

describe "Clicky tracking" do
  let(:user) { create(:user) }

  it "is present on regular pages" do
    get "/"
    expect(response.body).to include("static.getclicky.com")
  end

  it "does not send the user id" do
    sign_in(user)

    get "/dashboard"

    expect(response.body).to include("static.getclicky.com")
    expect(response.body).not_to include("clicky_custom")
  end

  it "is absent on the password reset page" do
    get "/users/password/edit", params: { reset_password_token: "secret-token" }
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("getclicky")
  end

  it "is absent on the sign in page" do
    get "/users/sign_in"
    expect(response.body).not_to include("getclicky")
  end

  it "is absent on the account deletion page" do
    sign_in(user)
    get "/account_deletion", params: { token: user.signed_id(purpose: :account_deletion) }
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("getclicky")
  end
end
