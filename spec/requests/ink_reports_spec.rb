require "rails_helper"

describe "InkReports" do
  let(:ink) { create(:macro_cluster, brand_name: "Diamine", line_name: "", ink_name: "Oxblood") }
  let(:path) { "/inks/#{ink.id}/report" }
  let(:user) { create(:user, email: "rita@example.com") }

  def delivered_mails
    Sidekiq::Worker.drain_all
    ActionMailer::Base.deliveries
  end

  it "requires authentication" do
    post path, params: { description: "Wrong ink" }
    expect(response).to redirect_to(new_user_session_path)
  end

  context "signed in" do
    before { sign_in(user) }

    it "emails the report" do
      post path, params: { description: "Two inks merged" }, as: :json

      expect(response).to have_http_status(:ok)
      mail = delivered_mails.sole
      expect(mail.subject).to eq("Ink error reported: Diamine Oxblood")
      expect(mail.reply_to).to eq(["rita@example.com"])
      expect(mail.text_part.body.decoded).to include("Two inks merged")
    end

    it "rejects a blank description" do
      post path, params: { description: "" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("errors" => ["Description can't be blank"])
      expect(delivered_mails).to be_empty
    end

    it "returns not found for an unknown ink" do
      post "/inks/0/report", params: { description: "Wrong ink" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(delivered_mails).to be_empty
    end
  end
end
