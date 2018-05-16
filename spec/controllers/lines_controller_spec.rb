require 'rails_helper'

describe LinesController do

  describe '#index' do

    let(:inks) do
      [
        create(:collected_ink, ink_name: 'Marine'),
        create(:collected_ink, brand_name: 'Robert Oster', line_name: 'Signature', ink_name: 'Fire & Ice'),
        create(:collected_ink, ink_name: 'Pumpkin'),
        create(:collected_ink, ink_name: 'Twilight'),
        create(:collected_ink, brand_name: 'Robert Oster', ink_name: 'Peppermint'),
        create(:collected_ink, brand_name: 'Pilot', line_name: 'Iroshizuku', ink_name: 'KonPeki')
      ]
    end

    before(:each) do
      inks # Load all the inks into the database
    end

    it 'returns all lines by default' do
      get :index, params: { term: '' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Iroshizuku", "Signature"])
    end

    it 'filters by term' do
      get :index, params: { term: 'Sig' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Signature"])
    end
  end

end
