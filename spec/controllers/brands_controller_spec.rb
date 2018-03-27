require 'rails_helper'

describe BrandsController do
  fixtures :collected_inks

  describe '#index' do

    before(:each) do
      # Trigger simplification
      CollectedInk.all.map(&:save)
    end

    it 'returns all brands by default' do
      get :index, params: { term: '' }, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq([{
        "simplified_brand_name"=>"diamine",
        "popular_name"=>"Diamine"
      },{
        "simplified_brand_name"=>"robertoster",
        "popular_name"=>"Robert Oster"
      }])
    end

    it 'filters by term' do
      get :index, params: { term: 'Dia' }, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq([{
        "simplified_brand_name"=>"diamine",
        "popular_name"=>"Diamine"
      }])
    end
  end
end
