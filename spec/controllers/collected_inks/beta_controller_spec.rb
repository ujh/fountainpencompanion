require 'rails_helper'

describe CollectedInks::BetaController do
  render_views

  let(:user) { create(:user) }

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'signed in' do
    before do
      sign_in(user)
    end

    it 'renders the ink index page' do
      create(:collected_ink, user: user, brand_name: 'Diamine')
      get :index
      expect(response).to be_successful
      expect(response.body).to include('Diamine')
    end

    it 'does not include archived entries' do
      create(:collected_ink, user: user, brand_name: 'Diamine', archived_on: Date.today)
      get :index
      expect(response).to be_successful
      expect(response.body).to_not include('Diamine')
    end

    it 'renders the CSV' do
      create(:collected_ink, user: user, brand_name: 'Diamine', ink_name: 'Meadow')
      create(:collected_ink, user: user, brand_name: 'Diamine', ink_name: 'Oxford Blue', archived_on: Date.today)
      get :index, format: 'csv'
      expect(response).to be_successful
      expect(response.body).to include('Meadow')
      expect(response.body).to include('Oxford Blue')
    end
  end
end
