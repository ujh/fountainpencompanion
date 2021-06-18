require 'rails_helper'

describe User do
  describe '#bot_field' do
    it 'sets the bot flag to true when this is set' do
      user = build(:user, bot_field: 'some value')
      expect(user).to be_bot
    end

    it 'sets the bot flag to false when this is set to 0' do
      user = build(:user, bot_field: '0')
      expect(user).not_to be_bot
    end

    it 'sets the bot flag to false when field is blank' do
      user = build(:user, bot_field: '')
      expect(user).to_not be_bot
    end

    it 'does not result in a validation error when the field is set' do
      user = build(:user, bot_field: 'some value')
      expect(user).to be_valid
    end

    it 'does nothing when user has already been persisted' do
      user = create(:user)
      user.bot_field = 'some value'
      expect(user.bot).to_not be true
    end

    it 'does not send a confirmation email when field is set' do
      expect do
        create(:user, confirmed_at: nil, bot_field: 'some value')
      end.to_not change { ActionMailer::Base.deliveries.count }
    end

    it 'sends a confirmation email when field is not set' do
      expect do
        create(:user, confirmed_at: nil, bot_field: '')
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'correctly sets bot_reason when marking as a bot via this method' do
      user = build(:user, bot_field: 'some value')
      expect(user.bot_reason).to eq('bot_field')
    end
  end

  describe '#sign_up_ip=' do
    it 'sets the ip field' do
      user = build(:user)
      user.sign_up_ip = '127.0.0.1'
      expect(user.sign_up_ip).to eq('127.0.0.1')
    end

    it 'does not set the bot field' do
      user = build(:user)
      user.sign_up_ip = '127.0.0.1'
      expect(user.bot).to be false
    end

    it 'sets the bot field if value in the blacklist' do
      user = build(:user)
      user.sign_up_ip = User::BLACKLIST.first
      expect(user.bot).to be true
    end

    it 'does not send a confirmation email when blacklisted' do
      expect do
        create(:user, confirmed_at: nil, sign_up_ip: User::BLACKLIST.first)
      end.to_not change { ActionMailer::Base.deliveries.count }
    end

    it 'marks as a bot when blacklisted, but not triggering the bot_field' do
      user = build(:user, sign_up_ip: User::BLACKLIST.first)
      user.bot_field = ''
      expect(user.bot).to be true
    end

    it 'correctly sets the bot_reason when marking as a bot via this method' do
      user = build(:user, sign_up_ip: User::BLACKLIST.first)
      expect(user.bot_reason).to eq('sign_up_ip_blacklist')
    end

    it 'marks as bot when too many signups by that IP in the last 24h' do
      create_list(:user, User::MAX_SAME_IP_24H, sign_up_ip: '123')
      user = build(:user, sign_up_ip: '123')
      expect(user.bot).to be true
    end

    it 'correctly sets the bot reason when too many signups in 24h' do
      create_list(:user, User::MAX_SAME_IP_24H, sign_up_ip: '123')
      user = build(:user, sign_up_ip: '123')
      expect(user.bot_reason).to eq('sign_up_ip_24h_timeframe')
    end
  end

  describe '#active_for_authentication?' do
    it 'returns true for confirmed users' do
      user = create(:user)
      expect(user).to be_active_for_authentication
    end

    it 'returns fals for bots' do
      user = create(:user, bot: true)
      expect(user).not_to be_active_for_authentication
    end
  end

  describe '#friends' do
    let(:friend) { create(:user) }
    subject { create(:user) }

    it 'includes user when I sent the friend request' do
      create(:friendship, sender: subject, friend: friend, approved: true)
      expect(subject.friends).to eq([friend])
    end

    it 'includes user when I received the friend request' do
      create(:friendship, sender: friend, friend: subject, approved: true)
      expect(subject.friends).to eq([friend])
    end

    it 'does not include requests that have not been approved' do
      create(:friendship, sender: subject, friend: friend, approved: false)
      expect(subject.friends).to eq([])
    end
  end

  describe '#friend?' do
    let(:friend) { create(:user) }
    subject { create(:user) }

    it 'true when I sent the friend request' do
      create(:friendship, sender: subject, friend: friend, approved: true)
      expect(subject.friend?(friend)).to eq(true)
    end

    it 'true when I received the friend request' do
      create(:friendship, sender: friend, friend: subject, approved: true)
      expect(subject.friend?(friend)).to eq(true)
    end

    it 'false when request not approved' do
      create(:friendship, sender: subject, friend: friend, approved: false)
      expect(subject.friend?(friend)).to eq(false)
    end
  end


  describe '#pending_friendships' do
    let(:friend) { create(:user) }
    subject { create(:user) }

    it 'includes user when I sent the friend request' do
      create(:friendship, sender: subject, friend: friend, approved: false)
      expect(subject.pending_friendships).to eq([friend])
    end

    it 'includes user when I received the friend request' do
      create(:friendship, sender: friend, friend: subject, approved: false)
      expect(subject.pending_friendships).to eq([friend])
    end
    it 'does not include approved friend requests' do
      create(:friendship, sender: subject, friend: friend, approved: true)
      expect(subject.pending_friendships).to eq([])
    end
  end

  describe '#pending_friendship' do
    let(:friend) { create(:user) }
    subject { create(:user) }

    it 'true when I sent the friend request' do
      create(:friendship, sender: subject, friend: friend, approved: false)
      expect(subject.pending_friendship?(friend)).to eq(true)
    end

    it 'true when I received the friend request' do
      create(:friendship, sender: friend, friend: subject, approved: false)
      expect(subject.pending_friendship?(friend)).to eq(true)
    end
    it 'false when friend request approved' do
      create(:friendship, sender: subject, friend: friend, approved: true)
      expect(subject.pending_friendship?(friend)).to eq(false)
    end
  end
end
