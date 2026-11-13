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

  describe "#ink_review_report" do
    let(:brand_cluster) { create(:brand_cluster) }
    let(:ink) do
      create(
        :macro_cluster,
        brand_cluster: brand_cluster,
        brand_name: "Diamine",
        line_name: "",
        ink_name: "Oxblood"
      )
    end
    let(:ink_review) do
      create(:ink_review, macro_cluster: ink, title: "Oxblood review", url: "https://example.com/r")
    end
    let(:user) { create(:user, name: "Rita Porter", email: "rita@example.com") }
    let(:mail) { described_class.ink_review_report(ink_review, user, "The video is gone") }

    it "sends to the admin address with the reporter as reply-to" do
      expect(mail.to).to eq(["hello@fountainpencompanion.com"])
      expect(mail.reply_to).to eq(["rita@example.com"])
    end

    it "names the review in the subject" do
      expect(mail.subject).to eq("Review reported: Oxblood review")
    end

    it "contains the description, the review, the ink and the reporter" do
      [mail.text_part, mail.html_part].each do |part|
        body = part.body.decoded
        expect(body).to include("The video is gone")
        expect(body).to include("Rita Porter")
        expect(body).to include("rita@example.com")
        expect(body).to include("https://example.com/r")
        expect(body).to include("Diamine Oxblood")
        expect(body).to include(ink_url(ink))
        expect(body).to include("/admins/users/#{user.id}")
      end
    end
  end

  describe "#ink_review_report escaping" do
    it "keeps HTML from the description out of the HTML part" do
      mail =
        described_class.ink_review_report(
          create(:ink_review),
          create(:user),
          "<script>alert(1)</script>"
        )

      expect(mail.html_part.body.decoded).not_to include("<script>")
    end
  end

  describe "#ink_report" do
    let(:brand_cluster) { create(:brand_cluster) }
    let(:ink) do
      create(
        :macro_cluster,
        brand_cluster: brand_cluster,
        brand_name: "Diamine",
        line_name: "",
        ink_name: "Oxblood"
      )
    end
    let(:user) { create(:user, name: "Rita Porter", email: "rita@example.com") }
    let(:mail) { described_class.ink_report(ink, user, "Wrong colour cluster") }

    it "sends to the admin address with the reporter as reply-to" do
      expect(mail.to).to eq(["hello@fountainpencompanion.com"])
      expect(mail.reply_to).to eq(["rita@example.com"])
    end

    it "names the ink in the subject" do
      expect(mail.subject).to eq("Ink error reported: Diamine Oxblood")
    end

    it "contains the description, the ink and the reporter" do
      [mail.text_part, mail.html_part].each do |part|
        body = part.body.decoded
        expect(body).to include("Wrong colour cluster")
        expect(body).to include("Rita Porter")
        expect(body).to include("rita@example.com")
        expect(body).to include(ink_url(ink))
        expect(body).to include("/admins/users/#{user.id}")
      end
    end

    it "does not link to the admin pages of the cluster, which only serve JSON" do
      [mail.text_part, mail.html_part].each do |part|
        expect(part.body.decoded).not_to include("/admins/macro_clusters")
      end
    end

    it "keeps HTML from the description out of the HTML part" do
      mail = described_class.ink_report(ink, user, "<script>alert(1)</script>")

      expect(mail.html_part.body.decoded).not_to include("<script>")
    end
  end

  describe "#pen_model_report" do
    let(:pen_model) { create(:pens_model, brand: "Pilot", model: "Custom 74") }
    let(:user) { create(:user, name: "Rita Porter", email: "rita@example.com") }
    let(:mail) { described_class.pen_model_report(pen_model, user, "Two models merged") }

    it "sends to the admin address with the reporter as reply-to" do
      expect(mail.to).to eq(["hello@fountainpencompanion.com"])
      expect(mail.reply_to).to eq(["rita@example.com"])
    end

    it "names the pen model in the subject" do
      expect(mail.subject).to eq("Pen model error reported: Pilot Custom 74")
    end

    it "contains the description, the pen model and the reporter" do
      [mail.text_part, mail.html_part].each do |part|
        body = part.body.decoded
        expect(body).to include("Two models merged")
        expect(body).to include("pen model Pilot Custom 74")
        expect(body).to include("rita@example.com")
        expect(body).to include(pen_model_url(pen_model))
        expect(body).to include("/admins/users/#{user.id}")
      end
    end
  end

  describe "#pen_variant_report" do
    let(:pen_variant) do
      create(:pens_model_variant, brand: "Pilot", model: "Custom 74", color: "Blue")
    end
    let(:user) { create(:user, name: "Rita Porter", email: "rita@example.com") }
    let(:mail) { described_class.pen_variant_report(pen_variant, user, "Wrong trim") }

    it "sends to the admin address with the reporter as reply-to" do
      expect(mail.to).to eq(["hello@fountainpencompanion.com"])
      expect(mail.reply_to).to eq(["rita@example.com"])
    end

    it "names the pen variant in the subject" do
      expect(mail.subject).to eq("Pen variant error reported: Pilot Custom 74 Blue")
    end

    it "contains the description, the pen variant and the reporter" do
      [mail.text_part, mail.html_part].each do |part|
        body = part.body.decoded
        expect(body).to include("Wrong trim")
        expect(body).to include("pen variant Pilot Custom 74 Blue")
        expect(body).to include("rita@example.com")
        expect(body).to include(pen_variant_url(pen_variant))
        expect(body).to include("/admins/users/#{user.id}")
      end
    end
  end
end
