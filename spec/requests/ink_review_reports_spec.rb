require "rails_helper"

describe "InkReviewReports" do
  let(:ink_review) { create(:ink_review, approved_at: Time.current, title: "Oxblood review") }
  let(:path) { "/ink_reviews/#{ink_review.id}/report" }
  let(:user) { create(:user, email: "rita@example.com") }

  def delivered_mails
    Sidekiq::Worker.drain_all
    ActionMailer::Base.deliveries
  end

  it "requires authentication" do
    post path, params: { description: "Broken" }
    expect(response).to redirect_to(new_user_session_path)
  end

  context "signed in" do
    before { sign_in(user) }

    it "emails the report" do
      post path, params: { description: "The video is gone" }, as: :json

      expect(response).to have_http_status(:ok)
      mail = delivered_mails.sole
      expect(mail.subject).to eq("Review reported: Oxblood review")
      expect(mail.reply_to).to eq(["rita@example.com"])
      expect(mail.text_part.body.decoded).to include("The video is gone")
    end

    it "accepts a JSON:API request body" do
      post path,
           params: { description: "The video is gone" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/vnd.api+json",
             "ACCEPT" => "application/vnd.api+json"
           }

      expect(response).to have_http_status(:ok)
      expect(delivered_mails.sole.text_part.body.decoded).to include("The video is gone")
    end

    it "rejects a blank description" do
      post path, params: { description: "  " }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("errors" => ["Description can't be blank"])
      expect(delivered_mails).to be_empty
    end

    it "rejects a missing description" do
      post path, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(delivered_mails).to be_empty
    end

    it "rejects a description that is too long" do
      post path, params: { description: "a" * 2001 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(delivered_mails).to be_empty
    end

    it "returns not found for a review that is not live" do
      queued_review = create(:ink_review)

      post "/ink_reviews/#{queued_review.id}/report", params: { description: "Broken" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(delivered_mails).to be_empty
    end
  end
end
