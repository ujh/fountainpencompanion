require "rails_helper"

describe SaveErrorReportEntry do
  let(:reporter) { create(:user, email: "rita@example.com") }
  let(:error_report) { create(:error_report, user: reporter) }
  let(:entry) { error_report.entries.build(user: create(:user, :admin)) }

  def delivered_mails
    Sidekiq::Worker.drain_all
    ActionMailer::Base.deliveries
  end

  it "saves a note without emailing the reporter or resolving the report" do
    saved = described_class.new(entry, { kind: "note", body: "Check it" }, resolve: true).perform

    expect(saved).to be(true)
    expect(entry).to be_persisted
    expect(delivered_mails).to be_empty
    expect(error_report.reload).not_to be_resolved
  end

  it "saves a reply and emails it to the reporter" do
    saved = described_class.new(entry, { kind: "reply", body: "Fixed, thanks!" }).perform

    expect(saved).to be(true)
    mail = delivered_mails.sole
    expect(mail.to).to eq(["rita@example.com"])
    expect(mail.text_part.body.decoded).to include("Fixed, thanks!")
    expect(error_report.reload).not_to be_resolved
  end

  it "resolves the report with a reply when asked" do
    described_class.new(entry, { kind: "reply", body: "Fixed, thanks!" }, resolve: true).perform

    expect(error_report.reload).to be_resolved
  end

  it "neither emails nor resolves when the entry is invalid" do
    saved = described_class.new(entry, { kind: "reply", body: "" }, resolve: true).perform

    expect(saved).to be(false)
    expect(entry).not_to be_persisted
    expect(delivered_mails).to be_empty
    expect(error_report.reload).not_to be_resolved
  end
end
