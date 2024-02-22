require "rails_helper"

describe "sign up" do
  context "normal user" do
    let(:user_params) do
      {
        email: "user@example.com",
        password: "password",
        password_confirmation: "password"
      }
    end

    before do
      stub_request(:post, "https://api.hcaptcha.com/siteverify").to_return(
        status: 200,
        body: { success: true }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end
    it "creates a user" do
      expect do
        post "/users", params: { user: user_params }
        expect(response).to be_redirect
      end.to change { User.where(bot: false).count }.by(1)
    end

    it "sends the confirmation email" do
      expect do
        post "/users", params: { user: user_params }
        expect(response).to be_redirect
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  context "bot user" do
    let(:user_params) do
      {
        email: "user@example.com",
        password: "password",
        password_confirmation: "password"
      }
    end

    before do
      stub_request(:post, "https://api.hcaptcha.com/siteverify").to_return(
        status: 200,
        body: { success: false, "error-codes": %w[not good] }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "creates a bot user" do
      expect do
        post "/users", params: { user: user_params }
        expect(response).to be_redirect
      end.to change { User.where(bot: true).count }.by(1)
    end

    it "does not send an email" do
      expect do
        post "/users", params: { user: user_params }
        expect(response).to be_redirect
      end.to_not change { ActionMailer::Base.deliveries.count }
    end
  end
end
