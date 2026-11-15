require "rails_helper"

describe AdminMailer do
  let(:markup) do
    "<a class=\"x\" href=\"https://evil.example\">link</a> <img src=\"https://evil.example/i.png\">"
  end

  describe "#agent_mail" do
    let(:mail) { described_class.agent_mail("Subject", "#{markup}\nsecond line\n\nnext paragraph") }

    it "shows markup in the body as text in the HTML part, keeping line breaks" do
      html = Nokogiri.HTML(mail.html_part.body.decoded)

      expect(
        html.css("a[href='https://evil.example'], img[src^='https://evil.example']")
      ).to be_empty
      expect(html.css("p").map(&:text)).to eq(["#{markup}\nsecond line", "next paragraph"])
      expect(html.css("p br").size).to eq(1)
    end

    it "keeps the body unchanged in the text part" do
      expect(mail.text_part.body.decoded).to include("#{markup}\nsecond line\n\nnext paragraph")
    end
  end

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
