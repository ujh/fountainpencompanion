require 'rails_helper'

describe InkBrand do

  describe '#update_popular_name!' do

    subject { InkBrand.create! }

    it 'correctly sets the popular name' do
      create(:collected_ink, brand_name: 'One', ink_brand: subject)
      create(:collected_ink, brand_name: 'Two', ink_brand: subject)
      create(:collected_ink, brand_name: 'Two', ink_brand: subject)
      subject.update_popular_name!
      expect(subject.popular_name).to eq('Two')
    end
  end

  describe '#public' do

    let!(:ink_brand) { InkBrand.create! }

    it 'does not return InkBrands without attached collected inks' do
      expect(InkBrand.count).to eq(1)
      expect(InkBrand.public.count).to eq(0)
    end

    it 'does not return InkBrands with only private collected inks' do
      create(:collected_ink, ink_brand: ink_brand, private: true)
      expect(InkBrand.public.count).to eq(0)
    end

    it 'returns InkBrands with only public collected inks' do
      create(:collected_ink, ink_brand: ink_brand, private: false)
      expect(InkBrand.public.count).to eq(1)
    end

    it 'returns InkBrands with collected inks of mixed privacy' do
      create(:collected_ink, ink_brand: ink_brand, private: false)
      create(:collected_ink, ink_brand: ink_brand, private: true)
      expect(InkBrand.public.count).to eq(1)
    end
  end
end
