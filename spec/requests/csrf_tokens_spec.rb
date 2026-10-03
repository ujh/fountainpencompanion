require "rails_helper"

describe "CSRF token refresh" do
  around do |example|
    original_value = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
    ActionController::Base.allow_forgery_protection = original_value
  end

  let(:user) { create(:user) }
  let(:currently_inked) { create(:currently_inked, user: user) }

  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  def fetch_token
    get "/csrf_token", headers: { "ACCEPT" => "application/json" }
    json[:token]
  end

  def record_usage(token)
    post "/currently_inked/#{currently_inked.id}/usage_record.json",
         headers: {
           "ACCEPT" => "application/vnd.api+json",
           "X-CSRF-Token" => token
         }
  end

  describe "GET /csrf_token" do
    it "returns a token" do
      get "/csrf_token", headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(json[:token]).to be_present
    end

    it "is not cacheable" do
      get "/csrf_token", headers: { "ACCEPT" => "application/json" }

      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "returns a token that is valid for subsequent requests of a signed in user" do
      # sign_in logs the user in on the next request, which (like a remember-me
      # login) rotates the session's CSRF token.
      sign_in(user)
      token = fetch_token

      expect { record_usage(token) }.to change { currently_inked.usage_records.count }.by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe "requests with an invalid token" do
    before { sign_in(user) }

    it "renders a JSON error for JSON requests" do
      expect { record_usage("stale-token") }.not_to change(UsageRecord, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:errors]).to eq(
        [{ code: "invalid_csrf_token", detail: "CSRF token verification failed" }]
      )
    end

    it "succeeds after refreshing the token" do
      record_usage("stale-token")
      expect(response).to have_http_status(:unprocessable_content)

      expect { record_usage(fetch_token) }.to change { currently_inked.usage_records.count }.by(1)
    end

    it "keeps the default error handling for HTML requests" do
      expect {
        post "/currently_inked/#{currently_inked.id}/usage_record",
             params: {
               authenticity_token: "stale-token"
             }
      }.not_to change(UsageRecord, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq("text/html")
    end
  end
end
