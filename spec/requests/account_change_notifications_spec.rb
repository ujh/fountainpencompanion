require "rails_helper"

describe "account change notifications" do
  let(:user) { create(:user, email: "old@example.com", password: "password123") }

  before { sign_in(user) }

  def delivered_mails
    Sidekiq::Worker.drain_all
    ActionMailer::Base.deliveries
  end

  it "notifies the old address when the email is changed" do
    put "/users", params: { user: { email: "new@example.com", current_password: "password123" } }

    notification = delivered_mails.find { |mail| mail.subject.end_with?("Email Changed") }
    expect(notification.to).to eq(["old@example.com"])
    expect(notification.body.encoded).to include("new@example.com")
  end

  it "sends a notification when the password is changed" do
    put "/users",
        params: {
          user: {
            password: "new-password-456",
            password_confirmation: "new-password-456",
            current_password: "password123"
          }
        }

    notification = delivered_mails.find { |mail| mail.subject.end_with?("Password Changed") }
    expect(notification.to).to eq(["old@example.com"])
  end
end
