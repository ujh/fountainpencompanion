require 'rails_helper'

describe BrandsController do

  describe '#index' do

    before(:each) do
      create_list(:collected_ink, 7, brand_name: 'Diamine')
      create_list(:collected_ink, 2, brand_name: 'Robert Oster')
      create(:collected_ink, brand_name: 'ROBERTOSTER ')
      create(:collected_ink, brand_name: 'diamine?!?')
      CollectedInk.find_each {|ci| SaveCollectedInk.new(ci, {}).perform }
    end

    it 'returns all brands by default' do
      get :index, params: { term: '' }, format: :jsonapi
      expect(response).to be_successful
      expect(JSON.parse(response.body)["data"]).to match_array([
        include(
          "type" => "brands",
          "attributes" => {
            "popular_name"=>"Diamine"
          }
        ),
        include(
          "type" => "brands",
          "attributes" => {
            "popular_name"=>"Robert Oster"
          }
        )
      ])
    end

    it 'filters by term' do
      get :index, params: { term: 'Dia' }, format: :jsonapi
      expect(response).to be_successful
      expect(JSON.parse(response.body)["data"]).to match_array([
        include(
          "type" => "brands",
          "attributes" => {
            "popular_name"=>"Diamine"
          }
        )
      ])
    end
  end
end
