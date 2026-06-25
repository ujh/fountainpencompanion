require "rails_helper"

describe User do
  describe "#sign_up_ip=" do
    it "sets the ip field" do
      user = build(:user)
      user.sign_up_ip = "127.0.0.1"
      expect(user.sign_up_ip).to eq("127.0.0.1")
    end

    it "does not set the bot field" do
      user = build(:user)
      user.sign_up_ip = "127.0.0.1"
      expect(user.bot).to be false
    end

    it "marks as bot when too many signups by that IP in the last 24h" do
      create_list(:user, User::MAX_SAME_IP_24H, sign_up_ip: "123")
      user = build(:user, sign_up_ip: "123")
      expect(user.bot).to be true
    end

    it "correctly sets the bot reason when too many signups in 24h" do
      create_list(:user, User::MAX_SAME_IP_24H, sign_up_ip: "123")
      user = build(:user, sign_up_ip: "123")
      expect(user.bot_reason).to eq("sign_up_ip_24h_timeframe")
    end
  end

  describe "#active_for_authentication?" do
    it "returns true for confirmed users" do
      user = create(:user)
      expect(user).to be_active_for_authentication
    end

    it "returns true for confirmed users with bot field set to true" do
      user = create(:user, confirmed_at: 1.day.ago, bot: true)
      expect(user).to be_active_for_authentication
    end

    it "returns false for bots" do
      user = create(:user, confirmed_at: nil, bot: true)
      expect(user).not_to be_active_for_authentication
    end

    it "returns false when deletion_requested_at is set" do
      user = create(:user, deletion_requested_at: Time.current)
      expect(user).not_to be_active_for_authentication
    end
  end

  describe ".match_patreon_members" do
    def member(user_id: nil, email: nil)
      PatreonClient::Member.new(
        member_id: "m",
        user_id: user_id,
        email: email,
        status: "active_patron",
        amount_cents: 500
      )
    end

    it "matches by linked patreon_user_id first, even when the email differs" do
      user = create(:user, email: "fpc@example.com", patreon_user_id: "u1")
      m = member(user_id: "u1", email: "other@example.com")
      expect(described_class.match_patreon_members([m])).to eq(m => user)
    end

    it "falls back to a case-insensitive email match" do
      user = create(:user, email: "match@example.com")
      m = member(email: "Match@Example.com")
      expect(described_class.match_patreon_members([m])).to eq(m => user)
    end

    it "maps unmatched members to nil" do
      m = member(user_id: "nope", email: "nobody@example.com")
      expect(described_class.match_patreon_members([m])).to eq(m => nil)
    end

    it "resolves a mix of members in one pass" do
      by_email = create(:user, email: "a@example.com")
      by_id = create(:user, email: "b@example.com", patreon_user_id: "u2")
      members = [
        member(email: "a@example.com"),
        member(user_id: "u2", email: "x@example.com"),
        member(email: "missing@example.com")
      ]
      expect(described_class.match_patreon_members(members).values).to eq([by_email, by_id, nil])
    end
  end
end
