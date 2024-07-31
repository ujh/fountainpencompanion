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

  describe "#friends" do
    let(:friend) { create(:user) }
    subject { create(:user) }

    it "includes user when I sent the friend request" do
      create(:friendship, sender: subject, friend: friend, approved: true)
      expect(subject.friends).to eq([friend])
    end

    it "includes user when I received the friend request" do
      create(:friendship, sender: friend, friend: subject, approved: true)
      expect(subject.friends).to eq([friend])
    end

    it "does not include requests that have not been approved" do
      create(:friendship, sender: subject, friend: friend, approved: false)
      expect(subject.friends).to eq([])
    end
  end

  describe "#friend?" do
    let(:friend) { create(:user) }
    subject { create(:user) }

    it "true when I sent the friend request" do
      create(:friendship, sender: subject, friend: friend, approved: true)
      expect(subject.friend?(friend)).to eq(true)
    end

    it "true when I received the friend request" do
      create(:friendship, sender: friend, friend: subject, approved: true)
      expect(subject.friend?(friend)).to eq(true)
    end

    it "false when request not approved" do
      create(:friendship, sender: subject, friend: friend, approved: false)
      expect(subject.friend?(friend)).to eq(false)
    end
  end

  describe "#pending_friendships" do
    let(:friend) { create(:user) }
    subject { create(:user) }

    it "includes user when I sent the friend request" do
      create(:friendship, sender: subject, friend: friend, approved: false)
      expect(subject.pending_friendships).to eq([friend])
    end

    it "includes user when I received the friend request" do
      create(:friendship, sender: friend, friend: subject, approved: false)
      expect(subject.pending_friendships).to eq([friend])
    end
    it "does not include approved friend requests" do
      create(:friendship, sender: subject, friend: friend, approved: true)
      expect(subject.pending_friendships).to eq([])
    end
  end

  describe "#pending_friendship" do
    let(:friend) { create(:user) }
    subject { create(:user) }

    it "true when I sent the friend request" do
      create(:friendship, sender: subject, friend: friend, approved: false)
      expect(subject.pending_friendship?(friend)).to eq(true)
    end

    it "true when I received the friend request" do
      create(:friendship, sender: friend, friend: subject, approved: false)
      expect(subject.pending_friendship?(friend)).to eq(true)
    end
    it "false when friend request approved" do
      create(:friendship, sender: subject, friend: friend, approved: true)
      expect(subject.pending_friendship?(friend)).to eq(false)
    end
  end
end
