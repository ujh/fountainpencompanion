require 'rails_helper'

describe BrandsController do
  fixtures :collected_inks

  describe '#index' do

    before(:each) do
      # Trigger simplification
      CollectedInk.all.map(&:save)
      sleep 1
    end

    it 'returns all brands by default' do
      get :index, params: { term: '' }, format: :jsonapi
      expect(response).to be_successful
      expect(JSON.parse(response.body)["data"]).to eq([{
        "id"=>"diamine",
        "type" => "brands",
        "attributes" => {
          "popular_name"=>"Diamine"
        }
      },{
        "id"=>"robertoster",
        "type" => "brands",
        "attributes" => {
          "popular_name"=>"Robert Oster"
        }
      }])
    end

    it 'filters by term' do
      get :index, params: { term: 'Dia' }, format: :jsonapi
      expect(response).to be_successful
      expect(JSON.parse(response.body)["data"]).to eq([{
        "id"=>"diamine",
        "type" => "brands",
        "attributes" => {
          "popular_name"=>"Diamine"
        }
      }])
    end
  end
end
