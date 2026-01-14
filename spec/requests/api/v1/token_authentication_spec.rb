require "rails_helper"

describe "API Token Authentication" do
  let(:user) { create(:user) }

  describe "authenticating with a valid token" do
    it "allows access to protected API endpoints" do
      token = create(:authentication_token, user: user)
      access_token = token.access_token

      get "/api/v1/collected_pens",
          headers: {
            "ACCEPT" => "application/json",
            "Authorization" => "Bearer #{access_token}"
          }

      expect(response).to have_http_status(:ok)
    end

    it "updates the last_used_at timestamp" do
      token = create(:authentication_token, user: user)
      access_token = token.access_token
      expect(token.last_used_at).to be_nil

      get "/api/v1/collected_pens",
          headers: {
            "ACCEPT" => "application/json",
            "Authorization" => "Bearer #{access_token}"
          }

      token.reload
      expect(token.last_used_at).to be_present
      expect(token.last_used_at).to be_within(5.seconds).of(Time.current)
    end

    it "returns data for the token owner" do
      create(:collected_pen, user: user, brand: "Pilot", model: "Custom 823")
      token = create(:authentication_token, user: user)

      get "/api/v1/collected_pens",
          headers: {
            "ACCEPT" => "application/json",
            "Authorization" => "Bearer #{token.access_token}"
          }

      expect(json[:data].length).to eq(1)
      expect(json[:data].first[:attributes][:brand]).to eq("Pilot")
    end
  end

  describe "authenticating with an invalid token" do
    it "returns unauthorized when token is wrong" do
      token = create(:authentication_token, user: user)

      get "/api/v1/collected_pens",
          headers: {
            "ACCEPT" => "application/json",
            "Authorization" => "Bearer #{token.id}.wrongtoken"
          }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized when token ID does not exist" do
      get "/api/v1/collected_pens",
          headers: {
            "ACCEPT" => "application/json",
            "Authorization" => "Bearer 999999.sometoken"
          }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized when token format is invalid" do
      get "/api/v1/collected_pens",
          headers: {
            "ACCEPT" => "application/json",
            "Authorization" => "Bearer invalidformat"
          }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized when Authorization header is empty" do
      get "/api/v1/collected_pens",
          headers: {
            "ACCEPT" => "application/json",
            "Authorization" => "Bearer "
          }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "authenticating with session (existing behavior)" do
    it "still works with session authentication" do
      sign_in(user)

      get "/api/v1/collected_pens", headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:ok)
    end

    it "requires authentication when no token or session" do
      get "/api/v1/collected_pens", headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "token for deleted user" do
    it "returns unauthorized when the user no longer exists" do
      token = create(:authentication_token, user: user)
      access_token = token.access_token

      # Manually delete the user without callbacks to preserve the token
      user.authentication_tokens.delete_all
      user.destroy

      get "/api/v1/collected_pens",
          headers: {
            "ACCEPT" => "application/json",
            "Authorization" => "Bearer #{access_token}"
          }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
