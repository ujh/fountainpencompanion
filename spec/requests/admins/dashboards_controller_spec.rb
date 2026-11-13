require "rails_helper"

describe Admins::DashboardsController do
  let(:admin) { create(:user, :admin) }

  describe "#show" do
    it "requires authentication" do
      get "/admins/dashboard"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders" do
        get "/admins/dashboard"
        expect(response).to be_successful
      end

      it "shows the number of open reports only as a link to the report queue" do
        get "/admins/dashboard"

        page = Nokogiri.HTML(response.body)
        expect(page.css(".stats[data-id='open_error_reports_count']")).to be_empty
        expect(
          page.at_css(".conditional-stats[data-id='open_error_reports_count']")["data-href"]
        ).to eq("/admins/error_reports")
      end

      it "serves the open report count to the dashboard refresh" do
        create(:error_report)

        get "/admins/stats/open_error_reports_count"

        expect(response.parsed_body).to eq(1)
      end
    end

    context "signed in as user" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "requires authentication" do
        get "/admins/dashboard"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "signed in as  admin user" do
      let(:user) { create(:user, :admin) }
      before(:each) { sign_in(user) }

      it "renders" do
        get "/admins/dashboard"
        expect(response).to be_successful
      end
    end
  end
end
