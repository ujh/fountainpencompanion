require 'rails_helper'

describe LinesController do
  fixtures :collected_inks

  describe '#index' do

    before(:each) do
      # Trigger simplification
      CollectedInk.all.map(&:save)
      sleep 1
    end

    it 'returns all lines by default' do
      get :index, params: { term: '' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Signature"])
    end

    it 'filters by term' do
      get :index, params: { term: 'Sig' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(["Signature"])
    end
  end

end
