require "rails_helper"

describe CustomMagicLinksController, type: :request do
  describe "GET /users/magic_link" do
    let(:user) { create(:user, password: "correct-horse") }

    def signed_in?
      get "/dashboard"
      response.status == 200
    end

    it "signs in with a valid emailed token" do
      get "/users/magic_link",
          params: {
            user: {
              email: user.email,
              token: user.encode_passwordless_token
            }
          }

      expect(response).to redirect_to(root_path)
      expect(signed_in?).to eq(true)
    end

    it "does not sign in with the correct password and no token" do
      get "/users/magic_link", params: { user: { email: user.email, password: "correct-horse" } }

      expect(response).not_to redirect_to(root_path)
      expect(signed_in?).to eq(false)
    end

    it "does not sign in with the correct password and an invalid token" do
      get "/users/magic_link",
          params: {
            user: {
              email: user.email,
              password: "correct-horse",
              token: "invalid"
            }
          }

      expect(response).not_to redirect_to(root_path)
      expect(signed_in?).to eq(false)
    end
  end
end
