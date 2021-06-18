require 'rails_helper'

describe LeaderBoard do

  describe '#currently_inked' do
    it 'orders users by their currently inked entries' do
      user1 = create(:user)
      create_list(:currently_inked, 3, user: user1)
      user2 = create(:user)
      create_list(:currently_inked, 2, user: user2)

      expect(described_class.currently_inked.map {|e| [e[:id], e[:counter]]}).to eq([
        [user1.id, 3], [user2.id, 2]
      ])
    end
  end

  describe '#top_currently_inked' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:currently_inked).and_return((1..20).to_a)
      expect(described_class.top_currently_inked).to eq((1..10).to_a)
    end
  end
  describe '#inks_by_popularity' do
    it 'orders by number of collected inks assigned to a macro cluster' do
      # One micro cluster that has three collected inks
      macro_cluster1 = create(:macro_cluster)
      micro_cluster11 = create(:micro_cluster, macro_cluster: macro_cluster1)
      create_list(:collected_ink, 3, micro_cluster: micro_cluster11)
      # Two micro clusters with one collected ink each
      macro_cluster2 = create(:macro_cluster)
      micro_cluster21 = create(:micro_cluster, macro_cluster: macro_cluster2)
      micro_cluster22 = create(:micro_cluster, macro_cluster: macro_cluster2)
      create(:collected_ink, micro_cluster: micro_cluster21)
      create(:collected_ink, micro_cluster: micro_cluster22)
      # One micro cluster with one collected ink
      macro_cluster3 = create(:macro_cluster)
      micro_cluster31 = create(:micro_cluster, macro_cluster: macro_cluster3)
      create(:collected_ink, micro_cluster: micro_cluster31)

      expect(described_class.inks_by_popularity.map {|mc| [mc.id, mc.ci_count]}).to eq([[
        macro_cluster1.id, 3
      ], [
        macro_cluster2.id, 2
      ], [
        macro_cluster3.id, 1
      ]])
    end
  end

  describe '#top_inks_by_popularity' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:inks_by_popularity).and_return((1..20).to_a)
      expect(described_class.top_inks_by_popularity).to eq((1..10).to_a)
    end
  end

  describe '#inks' do
    it 'orders users by their collected inks' do
      user1 = create(:user)
      create_list(:collected_ink, 3, user: user1)
      user2 = create(:user)
      create_list(:collected_ink, 2, user: user2)

      expect(described_class.inks.map {|e| [e[:id], e[:counter]]}).to eq([
        [user1.id, 3], [user2.id, 2]
      ])
    end

    it 'returns the user name' do
      user = create(:user, name: 'the name')
      create(:collected_ink, user: user)
      expect(described_class.inks.first).to include(public_name: 'the name')
    end

    it 'does not include users without inks' do
      user = create(:user)
      expect(described_class.inks).to be_empty
    end

    it 'does not include users with only private inks' do
      user = create(:user)
      create(:collected_ink, user: user, private: true)
      expect(described_class.inks).to be_empty
    end

    it 'does not count private inks' do
      user1 = create(:user)
      create_list(:collected_ink, 3, user: user1, private: true)
      create(:collected_ink, user: user1)
      user2 = create(:user)
      create_list(:collected_ink, 2, user: user2)

      expect(described_class.inks.map {|e| [e[:id], e[:counter]]}).to eq([
        [user2.id, 2], [user1.id, 1]
      ])
    end

    it 'returns the patreon status' do
      user = create(:user, patron: true)
      create(:collected_ink, user: user)
      expect(described_class.inks.first).to include(patron: true)
    end
  end

  describe '#top_inks' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:inks).and_return((1..20).to_a)
      expect(described_class.top_inks).to eq((1..10).to_a)
    end
  end

  describe '#bottles' do
    it 'orders users by their collected inks' do
      user1 = create(:user)
      create_list(:collected_ink, 3, user: user1, kind: 'bottle')
      user2 = create(:user)
      create_list(:collected_ink, 2, user: user2, kind: 'bottle')

      expect(described_class.bottles.map {|e| [e[:id], e[:counter]]}).to eq([
        [user1.id, 3], [user2.id, 2]
      ])
    end

    it 'does not count inks that are not bottles' do
      user1 = create(:user)
      create_list(:collected_ink, 1, user: user1, kind: 'bottle')
      create_list(:collected_ink, 3, user: user1, kind: 'sample')
      user2 = create(:user)
      create_list(:collected_ink, 2, user: user2, kind: 'bottle')

      expect(described_class.bottles.map {|e| [e[:id], e[:counter]]}).to eq([
        [user2.id, 2], [user1.id, 1]
      ])
    end
  end

  describe '#top_bottles' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:bottles).and_return((1..20).to_a)
      expect(described_class.top_bottles).to eq((1..10).to_a)
    end

  end

  describe '#samples' do
    it 'orders users by their collected inks' do
      user1 = create(:user)
      create_list(:collected_ink, 3, user: user1, kind: 'sample')
      user2 = create(:user)
      create_list(:collected_ink, 2, user: user2, kind: 'sample')

      expect(described_class.samples.map {|e| [e[:id], e[:counter]]}).to eq([
        [user1.id, 3], [user2.id, 2]
      ])
    end

    it 'does not count inks that are not bottles' do
      user1 = create(:user)
      create_list(:collected_ink, 1, user: user1, kind: 'sample')
      create_list(:collected_ink, 3, user: user1, kind: 'bottle')
      user2 = create(:user)
      create_list(:collected_ink, 2, user: user2, kind: 'sample')

      expect(described_class.samples.map {|e| [e[:id], e[:counter]]}).to eq([
        [user2.id, 2], [user1.id, 1]
      ])
    end

  end

  describe '#top_samples' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:samples).and_return((1..20).to_a)
      expect(described_class.top_samples).to eq((1..10).to_a)
    end
  end

  describe '#brands' do
    it 'orders users by their number of different brands' do
      user1 = create(:user)
      create(:collected_ink, user: user1, brand_name: 'brand 1')
      create(:collected_ink, user: user1, brand_name: 'brand 2')
      create(:collected_ink, user: user1, brand_name: 'brand 3')
      user2 = create(:user)
      create(:collected_ink, user: user2, brand_name: 'brand 1')
      create(:collected_ink, user: user2, brand_name: 'brand 2')

      expect(described_class.brands.map {|e| [e[:id], e[:counter]]}).to eq([
        [user1.id, 3], [user2.id, 2]
      ])
    end
  end

  describe '#top_brands' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:brands).and_return((1..20).to_a)
      expect(described_class.top_brands).to eq((1..10).to_a)
    end
  end
end
