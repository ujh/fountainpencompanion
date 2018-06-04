require 'rails_helper'

describe Pens::ModelsController do
  let(:user) { create(:user) }
  let(:wing_sung) { create(:collected_pen, user: user) }
  let(:custom74) { create(:collected_pen, user: user, brand: 'Pilot', model: 'Custom 74', nib: 'M', color: 'Orange') }
  let(:platinum) { create(:collected_pen, brand: 'Platinum', model: '3776 Chartres') }
  let(:pens) { [wing_sung, custom74, platinum] }

  before { pens }

  describe '#index' do

    it 'returns all models with an empty search term' do
      get :index, params: { term: ''}, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["3776 Chartres", "618", "Custom 74"])
    end

    it 'returns models by substring search' do
      get :index, params: { term: '7'}, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["3776 Chartres", "Custom 74"])
    end
  end

end
