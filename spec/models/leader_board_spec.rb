require 'rails_helper'

describe LeaderBoard do
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

  end

  describe '#top_inks' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:inks).and_return((1..20).to_a)
      expect(described_class.top_inks).to eq((1..10).to_a)
    end
  end

  describe '#bottles' do

  end

  describe '#top_bottles' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:bottles).and_return((1..20).to_a)
      expect(described_class.top_bottles).to eq((1..10).to_a)
    end

  end

  describe '#samples' do

  end

  describe '#top_samples' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:samples).and_return((1..20).to_a)
      expect(described_class.top_samples).to eq((1..10).to_a)
    end
  end

  describe '#brands' do

  end

  describe '#top_brands' do
    it 'returns the first 10 entries' do
      allow(described_class).to receive(:brands).and_return((1..20).to_a)
      expect(described_class.top_brands).to eq((1..10).to_a)
    end
  end
end
