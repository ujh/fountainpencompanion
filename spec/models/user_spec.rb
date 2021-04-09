require 'rails_helper'

describe User do
  describe '#bot_field' do
    it 'ensures that the user is valid if the field is not set' do
      user = build(:user)
      user.bot_field = ''
      expect(user).to be_valid
      user.bot_field = nil
      expect(user).to be_valid
    end

    it 'ensures that the user is invalid if the field is set' do
      user = build(:user)
      user.bot_field = 'some value'
      expect(user).to be_invalid
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
