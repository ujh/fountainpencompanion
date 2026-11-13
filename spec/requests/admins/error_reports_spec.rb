require "rails_helper"

describe "Admins::ErrorReports" do
  let(:admin) { create(:user, :admin, name: "Owner") }
  let(:reporter) { create(:user, email: "rita@example.com") }
  let(:ink) { create(:macro_cluster, brand_name: "Diamine", line_name: "", ink_name: "Oxblood") }
  let!(:error_report) do
    create(:error_report, user: reporter, reportable: ink, description: "Two inks merged")
  end

  def delivered_mails
    Sidekiq::Worker.drain_all
    ActionMailer::Base.deliveries
  end

  describe "access" do
    it "is limited to admins" do
      sign_in(create(:user))

      get "/admins/error_reports"
      expect(response).to redirect_to(new_user_session_path)

      get "/admins/error_reports/#{error_report.id}"
      expect(response).to redirect_to(new_user_session_path)

      patch "/admins/error_reports/#{error_report.id}", params: { resolved: "true" }
      expect(error_report.reload).not_to be_resolved

      post "/admins/error_reports/#{error_report.id}/entries",
           params: {
             error_report_entry: {
               kind: "note",
               body: "Hi"
             }
           }
      expect(ErrorReportEntry.count).to eq(0)
    end
  end

  context "as an admin" do
    before { sign_in(admin) }

    describe "GET /admins/error_reports" do
      let!(:resolved_report) do
        create(:error_report, description: "Already fixed", resolved_at: 1.day.ago)
      end

      it "lists the open reports by default" do
        get "/admins/error_reports"

        expect(response).to be_successful
        expect(response.body).to include("Two inks merged", "Diamine Oxblood", "rita@example.com")
        expect(response.body).not_to include("Already fixed")
      end

      it "lists the resolved reports" do
        get "/admins/error_reports", params: { status: "resolved" }

        expect(response.body).to include("Already fixed")
        expect(response.body).not_to include("Two inks merged")
      end

      it "lists all reports" do
        get "/admins/error_reports", params: { status: "all" }

        expect(response.body).to include("Already fixed", "Two inks merged")
      end

      it "shows the number of reports on each tab" do
        get "/admins/error_reports", params: { status: "resolved" }

        tabs = Nokogiri.HTML(response.body).css(".nav-tabs .nav-link").map { |tab| tab.text.strip }
        expect(tabs).to eq(["Open (1)", "Resolved (1)", "All (2)"])
      end

      it "links every cell of a report to the report page, not to the item" do
        get "/admins/error_reports"

        row = Nokogiri.HTML(response.body).at_css(".fpc-error-reports tbody tr")
        expect(row.css("td").map { |cell| cell.css("a").map { |link| link["href"] } }).to all(
          eq(["/admins/error_reports/#{error_report.id}"])
        )
      end

      it "falls back to the open reports for an unknown status" do
        get "/admins/error_reports", params: { status: "bogus" }

        expect(response.body).to include("Two inks merged")
        expect(response.body).not_to include("Already fixed")
      end
    end

    describe "GET /admins/error_reports/:id" do
      it "shows the report, its reporter and its history" do
        create(
          :error_report_entry,
          error_report: error_report,
          kind: "note",
          body: "Check the micro clusters"
        )
        create(
          :error_report_entry,
          error_report: error_report,
          kind: "reply",
          body: "Fixed, thanks!"
        )

        get "/admins/error_reports/#{error_report.id}"

        expect(response).to be_successful
        expect(response.body).to include(
          "Two inks merged",
          "rita@example.com",
          ink_url(ink),
          "Internal note",
          "Check the micro clusters",
          "Reply sent to user",
          "Fixed, thanks!"
        )
      end

      it "has breadcrumbs back to the report queue" do
        get "/admins/error_reports/#{error_report.id}"

        crumbs = Nokogiri.HTML(response.body).css(".fpc-breadcrumbs li")
        expect(crumbs.map { |crumb| crumb.text.strip }).to eq(
          ["Reports", "Ink report ##{error_report.id}"]
        )
        expect(crumbs.first.at_css("a")["href"]).to eq("/admins/error_reports")
      end

      it "shows the review's own URL for a review report" do
        review = create(:ink_review, url: "https://example.com/the-review")
        review_report = create(:error_report, reportable: review)

        get "/admins/error_reports/#{review_report.id}"

        expect(response.body).to include("https://example.com/the-review")
      end

      it "still shows a report whose item was deleted" do
        ink.destroy

        get "/admins/error_reports/#{error_report.id}"

        expect(response).to be_successful
        expect(response.body).to include("Diamine Oxblood", "no longer exists")
      end
    end

    describe "PATCH /admins/error_reports/:id" do
      it "marks the report resolved" do
        patch "/admins/error_reports/#{error_report.id}", params: { resolved: "true" }

        expect(error_report.reload).to be_resolved
        expect(response).to redirect_to("/admins/error_reports/#{error_report.id}")
      end

      it "reopens the report" do
        error_report.resolve!

        patch "/admins/error_reports/#{error_report.id}", params: { resolved: "false" }

        expect(error_report.reload).not_to be_resolved
      end
    end

    describe "POST /admins/error_reports/:id/entries" do
      let(:path) { "/admins/error_reports/#{error_report.id}/entries" }

      it "adds an internal note without emailing anyone" do
        post path,
             params: {
               error_report_entry: {
                 kind: "note",
                 body: "Check the micro clusters"
               }
             }

        expect(error_report.entries.sole).to have_attributes(
          kind: "note",
          body: "Check the micro clusters",
          user: admin
        )
        expect(error_report.reload).not_to be_resolved
        expect(delivered_mails).to be_empty
        expect(flash[:notice]).to eq("Note added.")
      end

      it "sends a reply to the reporter and records it" do
        post path, params: { error_report_entry: { kind: "reply", body: "Fixed, thanks!" } }

        expect(error_report.entries.sole).to have_attributes(kind: "reply", body: "Fixed, thanks!")
        mail = delivered_mails.sole
        expect(mail.to).to eq(["rita@example.com"])
        expect(mail.text_part.body.decoded).to include("Fixed, thanks!")
        expect(flash[:notice]).to eq("Reply sent to rita@example.com.")
      end

      it "resolves the report with the reply when asked" do
        post path,
             params: {
               error_report_entry: {
                 kind: "reply",
                 body: "Fixed, thanks!"
               },
               resolve: "1"
             }

        expect(error_report.reload).to be_resolved
      end

      it "keeps the report open after a reply when not asked to resolve" do
        post path, params: { error_report_entry: { kind: "reply", body: "Which inks?" } }

        expect(error_report.reload).not_to be_resolved
      end

      it "does not resolve the report with a note" do
        post path, params: { error_report_entry: { kind: "note", body: "Hmm" }, resolve: "1" }

        expect(error_report.reload).not_to be_resolved
      end

      it "rejects an empty entry" do
        post path, params: { error_report_entry: { kind: "reply", body: "" } }

        expect(ErrorReportEntry.count).to eq(0)
        expect(delivered_mails).to be_empty
        expect(flash[:alert]).to eq("Body can't be blank")
      end
    end
  end
end
