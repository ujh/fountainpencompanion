require 'rails_helper'

describe InkBrand do

  let!(:ink_brand) { InkBrand.create! }

  describe '#update_popular_name!' do

    it 'correctly sets the popular name' do
      ink_name = create(:new_ink_name, ink_brand: ink_brand)
      create(:collected_ink, brand_name: 'One', new_ink_name: ink_name)
      create(:collected_ink, brand_name: 'Two', new_ink_name: ink_name)
      create(:collected_ink, brand_name: 'Two', new_ink_name: ink_name)
      ink_brand.update_popular_name!
      expect(ink_brand.popular_name).to eq('Two')
    end

  end

  describe '#public' do

    it 'does not return InkBrands without attached collected inks' do
      expect(InkBrand.count).to eq(1)
      expect(InkBrand.public).to be_empty
    end

    it 'does not return InkBrands with only private collected inks' do
      ink_name = create(:new_ink_name, ink_brand: ink_brand)
      create(:collected_ink, private: true, new_ink_name: ink_name)
      expect(InkBrand.public).to be_empty
    end

    it 'returns InkBrands with only public collected inks' do
      ink_name = create(:new_ink_name, ink_brand: ink_brand)
      create(:collected_ink, private: false, new_ink_name: ink_name)
      expect(InkBrand.public).to eq([ink_brand])
    end

    it 'returns InkBrands with collected inks of mixed privacy' do
      ink_name = create(:new_ink_name, ink_brand: ink_brand)
      create(:collected_ink, private: false, new_ink_name: ink_name)
      create(:collected_ink, private: true, new_ink_name: ink_name)
      expect(InkBrand.public).to eq([ink_brand])
    end

    it 'returns the count of visible new ink names' do
      visible_ink_name = create(:new_ink_name, ink_brand: ink_brand)
      create(:collected_ink, private: false, new_ink_name: visible_ink_name)
      create(:collected_ink, private: false, new_ink_name: visible_ink_name)
      hidden_ink_name = create(:new_ink_name, ink_brand: ink_brand)
      create(:collected_ink, private: true, new_ink_name: hidden_ink_name)
      create(:collected_ink, private: true, new_ink_name: hidden_ink_name)
      expect(InkBrand.public).to eq([ink_brand])
      brand = InkBrand.public.first
      expect(brand.new_ink_names_count).to eq(1)
    end
  end

  describe '#empty' do

    it 'includes brands without new ink names' do
      expect(described_class.empty).to eq([ink_brand])
    end

    it 'does not include brands with new ink names' do
      create(:new_ink_name, ink_brand: ink_brand)
      expect(described_class.empty).to be_empty
    end
  end
end
