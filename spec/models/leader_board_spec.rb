require 'rails_helper'

describe LeaderBoard do
  describe '#inks_by_popularity' do

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
