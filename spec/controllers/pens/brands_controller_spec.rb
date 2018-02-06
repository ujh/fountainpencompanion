require 'rails_helper'

describe Pens::BrandsController do
  fixtures :collected_pens

  describe '#index' do

    it 'returns all brands with an empty search term' do
      get :index, params: { term: ''}, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Pilot", "Platinum", "Wing Sung"])
    end

    it 'returns brands by substring search' do
      get :index, params: { term: 'P'}, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Pilot", "Platinum"])
    end
  end
end
