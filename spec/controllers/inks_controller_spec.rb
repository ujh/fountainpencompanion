require 'rails_helper'

describe InksController do
  fixtures :collected_inks

  describe '#index' do

    before(:each) do
      # Trigger simplification
      CollectedInk.all.map(&:save)
      sleep 1
    end

    it 'returns all inks by default' do
      get :index, params: { term: '' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Fire & Ice", "Marine"])
    end

    it 'filters by term' do
      get :index, params: { term: 'Mar' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Marine"])
    end
  end


end
