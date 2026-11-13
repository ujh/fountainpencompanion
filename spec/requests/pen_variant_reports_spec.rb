require "rails_helper"

describe "PenVariantReports" do
  let(:record) { create(:pens_model_variant, brand: "Pilot", model: "Custom 74") }
  let(:path) { "/pen_variants/#{record.id}/report" }
  let(:user) { create(:user, email: "rita@example.com") }

  def delivered_mails
    Sidekiq::Worker.drain_all
    ActionMailer::Base.deliveries
  end

  it "requires authentication" do
    post path, params: { description: "Wrong" }
    expect(response).to redirect_to(new_user_session_path)
  end

  context "signed in" do
    before { sign_in(user) }

    it "emails the report" do
      post path, params: { description: "Two pens merged" }, as: :json

      expect(response).to have_http_status(:ok)
      mail = delivered_mails.sole
      expect(mail.subject).to eq("Pen variant error reported: Pilot Custom 74")
      expect(mail.reply_to).to eq(["rita@example.com"])
      expect(mail.text_part.body.decoded).to include("Two pens merged")
    end

    it "rejects a blank description" do
      post path, params: { description: "" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("errors" => ["Description can't be blank"])
      expect(delivered_mails).to be_empty
    end

    it "returns not found for an unknown record" do
      post "/pen_variants/0/report", params: { description: "Wrong" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(delivered_mails).to be_empty
    end
  end
end
