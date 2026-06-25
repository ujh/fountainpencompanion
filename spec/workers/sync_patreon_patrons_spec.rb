require "rails_helper"

describe SyncPatreonPatrons do
  def member(member_id:, user_id: nil, email: nil, status: "active_patron", amount: 500)
    PatreonClient::Member.new(
      member_id: member_id,
      user_id: user_id,
      email: email,
      status: status,
      amount_cents: amount
    )
  end

  def stub_members(members)
    PatreonCredential.create!(access_token: "t", refresh_token: "r", expires_at: 1.hour.from_now)
    client = instance_double(PatreonClient, members: members)
    allow(PatreonClient).to receive(:new).and_return(client)
  end

  around do |example|
    previous = ENV["PATREON_CAMPAIGN_ID"]
    ENV["PATREON_CAMPAIGN_ID"] = "campaign-1"
    example.run
    ENV["PATREON_CAMPAIGN_ID"] = previous
  end

  it "grants patron status by email match" do
    user = create(:user, email: "match@example.com", patron: false)
    stub_members([member(member_id: "m1", user_id: "u1", email: "Match@Example.com")])

    described_class.new.perform

    user.reload
    expect(user.patron).to be(true)
    expect(user.patron_source).to eq("patreon")
    expect(user.patreon_member_id).to eq("m1")
    expect(user.patreon_user_id).to eq("u1")
    expect(user.patreon_status).to eq("active_patron")
    expect(user.patreon_synced_at).to be_present
  end

  it "grants by linked patreon_user_id even when the email differs" do
    user = create(:user, email: "fpc@example.com", patreon_user_id: "u99", patron: false)
    stub_members([member(member_id: "m1", user_id: "u99", email: "different@example.com")])

    described_class.new.perform

    expect(user.reload.patron).to be(true)
  end

  it "ignores members that do not match any user" do
    create(:user, email: "someone@example.com", patron: false)
    stub_members([member(member_id: "m1", user_id: "u1", email: "nobody@example.com")])

    expect { described_class.new.perform }.not_to(change { User.where(patron: true).count })
  end

  it "leaves admin-pinned (manual) users untouched" do
    user = create(:user, email: "manual@example.com", patron: true, patron_source: "manual")
    stub_members([])

    described_class.new.perform

    user.reload
    expect(user.patron).to be(true)
    expect(user.patron_source).to eq("manual")
  end

  it "revokes patrons it previously granted once they are no longer active" do
    user =
      create(
        :user,
        email: "churned@example.com",
        patron: true,
        patron_source: "patreon",
        patreon_member_id: "m1"
      )
    stub_members([]) # no active members this run

    described_class.new.perform

    user.reload
    expect(user.patron).to be(false)
    expect(user.patreon_status).to eq("former_patron")
  end

  it "never revokes legacy/unmanaged (NULL source) patrons" do
    user = create(:user, email: "legacy@example.com", patron: true, patron_source: nil)
    stub_members([])

    described_class.new.perform

    expect(user.reload.patron).to be(true)
  end

  it "treats declined or zero-pledge members as inactive" do
    create(:user, email: "declined@example.com", patron: false)
    stub_members(
      [member(member_id: "m1", email: "declined@example.com", status: "declined_patron")]
    )

    described_class.new.perform

    expect(User.find_by(email: "declined@example.com").patron).to be(false)
  end

  it "does nothing when no credential is configured" do
    user = create(:user, email: "x@example.com", patron: false)
    expect(PatreonClient).not_to receive(:new)

    described_class.new.perform

    expect(user.reload.patron).to be(false)
  end
end
