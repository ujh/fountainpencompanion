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

  describe "#error_report_reply" do
    let(:ink) { create(:macro_cluster, brand_name: "Diamine", line_name: "", ink_name: "Oxblood") }
    let(:reporter) { create(:user, name: "Rita", email: "rita@example.com") }
    let(:error_report) do
      create(:error_report, user: reporter, reportable: ink, description: "Two inks merged")
    end
    let(:entry) do
      create(:error_report_entry, error_report: error_report, kind: "reply", body: "Fixed, thanks!")
    end
    let(:mail) { described_class.error_report_reply(entry) }

    it "sends to the reporter, with replies going to hello@" do
      expect(mail.to).to eq(["rita@example.com"])
      expect(mail.reply_to).to eq(["hello@fountainpencompanion.com"])
    end

    it "names the reported item in the subject" do
      expect(mail.subject).to eq("About your report: Diamine Oxblood")
    end

    it "contains the reply, the original report and a link to the item" do
      [mail.text_part, mail.html_part].each do |part|
        body = part.body.decoded
        expect(body).to include("Hi Rita")
        expect(body).to include("Fixed, thanks!")
        expect(body).to include("Two inks merged")
        expect(body).to include(ink_url(ink))
      end
    end

    it "leaves out the link when the item no longer exists" do
      entry
      ink.destroy
      mail = described_class.error_report_reply(ErrorReportEntry.find(entry.id))

      expect(mail.text_part.body.decoded).to include("Diamine Oxblood")
      expect(mail.text_part.body.decoded).not_to include("/inks/")
      expect(mail.html_part.body.decoded).not_to include("/inks/")
    end

    it "keeps HTML from the reply and the report out of the HTML part" do
      error_report.update!(description: "<script>alert(1)</script>")
      entry.update!(body: "<script>alert(2)</script>")

      expect(mail.html_part.body.decoded).not_to include("<script>")
    end
  end
end
