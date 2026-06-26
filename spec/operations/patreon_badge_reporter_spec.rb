require "rails_helper"

describe PatreonBadgeReporter do
  def patron(**attrs)
    create(
      :user,
      { patron: true, patron_source: "patreon", patreon_badge_reported_at: nil }.merge(attrs)
    )
  end

  it "emails the admin and stamps reported_at for unreported patreon patrons" do
    user = patron
    mailer = double(deliver_later: true)
    expect(AdminMailer).to receive(:patreon_badges_to_deliver) do |users|
      expect(users.map(&:id)).to eq([user.id])
      mailer
    end

    described_class.new([user]).perform

    expect(user.reload.patreon_badge_reported_at).to be_present
  end

  it "skips users that are not patreon-sourced patrons" do
    manual = patron(patron_source: "manual")
    legacy = patron(patron_source: nil)
    not_patron = patron(patron: false, patron_source: "patreon")
    expect(AdminMailer).not_to receive(:patreon_badges_to_deliver)

    described_class.new([manual, legacy, not_patron]).perform

    expect(manual.reload.patreon_badge_reported_at).to be_nil
  end

  it "skips users already reported" do
    reported = patron(patreon_badge_reported_at: 1.day.ago)
    expect(AdminMailer).not_to receive(:patreon_badges_to_deliver)

    described_class.new([reported]).perform
  end

  it "reports only the pending users when given a mix" do
    pending = patron
    reported = patron(patreon_badge_reported_at: 1.day.ago)
    expect(AdminMailer).to receive(:patreon_badges_to_deliver) do |users|
      expect(users.map(&:id)).to eq([pending.id])
      double(deliver_later: true)
    end

    described_class.new([pending, reported]).perform
  end
end
