require "rails_helper"

describe AdminMailer do
  describe "#patreon_badges_to_deliver" do
    let(:user) do
      create(
        :user,
        name: "Pat Ron",
        email: "pat@example.com",
        patreon_user_id: "pu-42",
        patreon_email: "pat@patreon.example"
      )
    end
    let(:mail) { described_class.patreon_badges_to_deliver([user]) }

    it "sends to the admin address" do
      expect(mail.to).to eq(["hello@fountainpencompanion.com"])
    end

    it "puts the count in the subject" do
      expect(mail.subject).to eq("1 Patreon badge(s) to mark delivered")
    end

    it "lists each patron's details" do
      body = mail.body.encoded
      expect(body).to include("Pat Ron")
      expect(body).to include("pat@example.com")
      expect(body).to include("pat@patreon.example")
      expect(body).to include("pu-42")
    end

    it "mentions the benefit to mark delivered" do
      expect(mail.body.encoded).to match(/Add badge/)
    end
  end
end
