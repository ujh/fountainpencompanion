require "rails_helper"

describe YouTubeChannel do
  describe "#channel_ids_for_reviews" do
    it "returns a channel that has at least 3 approved reviews" do
      channel = create(:you_tube_channel)
      create_list(:ink_review, 3, you_tube_channel: channel, approved_at: Time.now)
      expect(described_class.channel_ids_for_reviews).to eq([channel.channel_id])
    end

    it "does not return a channel with 2 approved reviews" do
      channel = create(:you_tube_channel)
      create_list(:ink_review, 2, you_tube_channel: channel, approved_at: Time.now)
      expect(described_class.channel_ids_for_reviews).to eq([])
    end

    it "does not return a channel with unapproved reviews" do
      channel = create(:you_tube_channel)
      create_list(:ink_review, 3, you_tube_channel: channel, approved_at: nil)
      expect(described_class.channel_ids_for_reviews).to eq([])
    end

    it "does not return a channel with rejected reviews" do
      channel = create(:you_tube_channel)
      create_list(:ink_review, 3, you_tube_channel: channel, rejected_at: nil)
      expect(described_class.channel_ids_for_reviews).to eq([])
    end

    it "does not return a channel with no reviews" do
      channel = create(:you_tube_channel)
      expect(described_class.channel_ids_for_reviews).to eq([])
    end
  end
end
