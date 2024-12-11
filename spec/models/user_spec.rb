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
  end
end
