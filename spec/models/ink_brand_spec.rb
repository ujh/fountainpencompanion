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
end
