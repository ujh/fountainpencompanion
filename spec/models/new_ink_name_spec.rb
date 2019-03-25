require 'rails_helper'

describe NewInkName do

  describe '#public' do

    it 'excludes inks without collected inks' do
      create(:new_ink_name)
      expect(described_class.public).to be_empty
    end

    it 'includes inks with collected inks' do
      ink = create(:new_ink_name)
      create(:collected_ink, new_ink_name: ink)
      expect(described_class.public).to eq([ink])
    end

    it 'does not include inks with only private collected inks' do
      ink = create(:new_ink_name)
      create(:collected_ink, new_ink_name: ink, private: true)
      expect(described_class.public).to be_empty
    end

    it 'includes inks with at least one public collected ink' do
      ink = create(:new_ink_name)
      create(:collected_ink, new_ink_name: ink)
      create(:collected_ink, new_ink_name: ink, private: true)
      expect(described_class.public).to eq([ink])
    end

    it 'includes each ink only once' do
      ink = create(:new_ink_name)
      create(:collected_ink, new_ink_name: ink)
      create(:collected_ink, new_ink_name: ink)
      expect(described_class.public).to eq([ink])
    end

    it 'returns the number of public collected_inks as a computed attribute' do
      ink = create(:new_ink_name)
      create(:collected_ink, new_ink_name: ink)
      create(:collected_ink, new_ink_name: ink)
      create(:collected_ink, new_ink_name: ink, private: true)
      expect(described_class.public).to eq([ink])
      ink = described_class.public.first
      expect(ink.collected_inks_count).to eq(2)
    end
  end

  describe '#empty' do

    it 'includes inks without collected inks' do
      ink = create(:new_ink_name)
      expect(described_class.empty).to eq([ink])
    end

    it 'does not include inks with private collected inks' do
      ink = create(:new_ink_name)
      create(:collected_ink, new_ink_name: ink, private: true)
      expect(described_class.empty).to be_empty
    end

    it 'does not include inks with public collected inks' do
      ink = create(:new_ink_name)
      create(:collected_ink, new_ink_name: ink)
      expect(described_class.empty).to be_empty
    end

  end
end