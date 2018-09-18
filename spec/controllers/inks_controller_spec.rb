require 'rails_helper'

describe InksController do

  describe '#index' do

    let(:inks) do
      [
        create(:collected_ink, ink_name: 'Marine'),
        create(:collected_ink, brand_name: 'Robert Oster', ink_name: 'Fire & Ice'),
        create(:collected_ink, ink_name: 'Pumpkin'),
        create(:collected_ink, ink_name: 'Twilight'),
        create(:collected_ink, brand_name: 'Robert Oster', ink_name: 'Peppermint')
      ]
    end

    before(:each) do
      inks.each {|ci| SaveCollectedInk.new(ci, {}).perform }
    end

    it 'returns all inks by default' do
      get :index, params: { term: '' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Fire & Ice", "Marine", "Peppermint", "Pumpkin", "Twilight"])
    end

    it 'filters by term' do
      get :index, params: { term: 'Mar' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Marine"])
    end
  end
end
