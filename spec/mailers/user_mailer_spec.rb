require "rails_helper"

describe UserMailer do
  let(:user) { create(:user) }

  describe "#account_deletion_confirmation" do
    let(:mail) { described_class.account_deletion_confirmation(user) }

    it "sends to the user's email" do
      expect(mail.to).to eq([user.email])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("Confirm your account deletion")
    end

    it "includes a confirmation link in the body" do
      expect(mail.body.encoded).to match(/account_deletion/)
      expect(mail.body.encoded).to match(/token=/)
    end
  end
end
