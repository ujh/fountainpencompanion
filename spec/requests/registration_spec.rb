require "rails_helper"

describe "sign up" do
  let(:user_params) do
    { email: "user@example.com", password: "password", password_confirmation: "password" }
  end

  let(:full_params) { { :user => user_params, "h-captcha-response" => "valid-token" } }

  context "captcha passes" do
    before do
      stub_request(:post, "https://api.hcaptcha.com/siteverify").to_return(
        status: 200,
        body: { success: true }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "creates a non-bot user" do
      expect { post "/users", params: full_params }.to change { User.where(bot: false).count }.by(1)
      expect(response).to be_redirect
    end

    it "sends the confirmation email" do
      expect do
        post "/users", params: full_params
        Sidekiq::Worker.drain_all
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "sends the request IP to hCaptcha" do
      post "/users", params: full_params, env: { "REMOTE_ADDR" => "203.0.113.55" }

      expect(WebMock).to have_requested(:post, "https://api.hcaptcha.com/siteverify").with(
        body: hash_including("remoteip" => "203.0.113.55")
      )
    end
  end

  context "captcha fails (hCaptcha returns success: false)" do
    before do
      stub_request(:post, "https://api.hcaptcha.com/siteverify").to_return(
        status: 200,
        body: { success: false, "error-codes": %w[invalid-input-response] }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "does not create any user" do
      expect { post "/users", params: full_params }.not_to(change { User.count })
    end

    it "re-renders the signup form with a base error" do
      post "/users", params: full_params
      expect(response.body).to include("captcha")
    end

    it "does not send any email" do
      expect do
        post "/users", params: full_params
        Sidekiq::Worker.drain_all
      end.not_to(change { ActionMailer::Base.deliveries.count })
    end
  end

  context "captcha token missing entirely" do
    it "does not create a user and does not call hCaptcha" do
      stub = stub_request(:post, "https://api.hcaptcha.com/siteverify")

      expect { post "/users", params: { user: user_params } }.not_to(change { User.count })

      expect(stub).not_to have_been_requested
    end
  end

  context "hCaptcha service is unreachable (fail-closed)" do
    before do
      stub_request(:post, "https://api.hcaptcha.com/siteverify").to_raise(
        Faraday::ConnectionFailed.new("network down")
      )
    end

    it "treats the network error as a captcha failure and does not create a user" do
      expect { post "/users", params: full_params }.not_to(change { User.count })
    end
  end

  context "hCaptcha returns malformed body (fail-closed)" do
    before do
      stub_request(:post, "https://api.hcaptcha.com/siteverify").to_return(
        status: 200,
        body: "not json",
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "treats the parse error as a captcha failure and does not create a user" do
      expect { post "/users", params: full_params }.not_to(change { User.count })
    end
  end
end
