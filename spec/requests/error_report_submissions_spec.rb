require "rails_helper"

describe "Error report submissions" do
  let(:user) { create(:user) }

  shared_examples "an error report endpoint" do |path_prefix|
    let(:path) { "/#{path_prefix}/#{record.id}/report" }

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
        expect(ErrorReport.last).to have_attributes(
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
        post "/#{path_prefix}/0/report", params: { description: "Wrong" }, as: :json

        expect(response).to have_http_status(:not_found)
        expect(ErrorReport.count).to eq(0)
      end
    end
  end

  describe "POST /ink_reviews/:id/report" do
    let(:record) { create(:ink_review, approved_at: Time.current) }

    include_examples "an error report endpoint", "ink_reviews"

    it "returns not found for a review that is not live" do
      sign_in(user)

      post "/ink_reviews/#{create(:ink_review).id}/report",
           params: {
             description: "Broken"
           },
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(ErrorReport.count).to eq(0)
    end
  end

  describe "POST /inks/:id/report" do
    let(:record) { create(:macro_cluster) }

    include_examples "an error report endpoint", "inks"
  end

  describe "POST /pen_models/:id/report" do
    let(:record) { create(:pens_model) }

    include_examples "an error report endpoint", "pen_models"
  end

  describe "POST /pen_variants/:id/report" do
    let(:record) { create(:pens_model_variant) }

    include_examples "an error report endpoint", "pen_variants"
  end
end
