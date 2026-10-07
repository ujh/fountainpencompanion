require "rails_helper"

describe Admins::CspReportsController do
  describe "#index" do
    it "requires an admin" do
      sign_in(create(:user))

      get "/admins/csp_reports"

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists reported violations" do
      sign_in(create(:user, :admin))
      CspReport.create!(
        directive: "script-src-elem",
        blocked_uri: "https://evil.example.com",
        page: "brands#index",
        count: 3,
        sample: "alert(1)"
      )

      get "/admins/csp_reports"

      expect(response).to be_successful
      expect(response.body).to include("https://evil.example.com", "brands#index", "alert(1)")
    end

    it "shows an empty state" do
      sign_in(create(:user, :admin))

      get "/admins/csp_reports"

      expect(response.body).to include("No Content Security Policy violations reported.")
    end
  end
end
