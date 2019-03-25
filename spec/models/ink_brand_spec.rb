require 'rails_helper'

describe InkBrand do

  describe '#update_popular_name!' do

    subject { InkBrand.create! }

    it 'correctly sets the popular name' do
      ink_name = create(:new_ink_name, ink_brand: subject)
      create(:collected_ink, brand_name: 'One', new_ink_name: ink_name)
      create(:collected_ink, brand_name: 'Two', new_ink_name: ink_name)
      create(:collected_ink, brand_name: 'Two', new_ink_name: ink_name)
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
      ink_name = create(:new_ink_name, ink_brand: ink_brand)
      create(:collected_ink, private: true, new_ink_name: ink_name)
      expect(InkBrand.public.count).to eq(0)
    end

    it 'returns InkBrands with only public collected inks' do
      ink_name = create(:new_ink_name, ink_brand: ink_brand)
      create(:collected_ink, private: false, new_ink_name: ink_name)
      expect(InkBrand.public.count).to eq(1)
    end

    it 'returns InkBrands with collected inks of mixed privacy' do
      ink_name = create(:new_ink_name, ink_brand: ink_brand)
      create(:collected_ink, private: false, new_ink_name: ink_name)
      create(:collected_ink, private: true, new_ink_name: ink_name)
      expect(InkBrand.public.count).to eq(1)
    end
  end
end
