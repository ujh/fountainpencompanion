require "rails_helper"

describe "PenModelReports" do
  let(:record) { create(:pens_model) }
  let(:path) { "/pen_models/#{record.id}/report" }
  let(:user) { create(:user) }

  it "requires authentication" do
    post path, params: { description: "Wrong" }
    expect(response).to redirect_to(new_user_session_path)
  end

  context "signed in" do
    before { sign_in(user) }

    it "stores the report without sending an email" do
      expect { post path, params: { description: "Something is wrong" }, as: :json }.to change(
        ErrorReport,
        :count
      ).by(1)

      expect(response).to have_http_status(:ok)
      report = ErrorReport.last
      expect(report).to have_attributes(
        user: user,
        reportable: record,
        description: "Something is wrong",
        resolved_at: nil
      )
      Sidekiq::Worker.drain_all
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "accepts a JSON:API request body" do
      post path,
           params: { description: "Something is wrong" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/vnd.api+json",
             "ACCEPT" => "application/vnd.api+json"
           }

      expect(response).to have_http_status(:ok)
      expect(ErrorReport.last.description).to eq("Something is wrong")
    end

    it "rejects a blank description" do
      expect { post path, params: { description: "  " }, as: :json }.not_to change(
        ErrorReport,
        :count
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("errors" => ["Description can't be blank"])
    end

    it "rejects a description that is too long" do
      post path, params: { description: "a" * 2001 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(ErrorReport.count).to eq(0)
    end

    it "returns not found for an unknown record" do
      post "/pen_models/0/report", params: { description: "Wrong" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(ErrorReport.count).to eq(0)
    end
  end
end
