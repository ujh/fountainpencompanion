require 'rails_helper'

describe CollectedInks::BetaArchiveController do
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
      create(:collected_ink, user: user, brand_name: 'Diamine', archived_on: Date.today)
      get :index
      expect(response).to be_successful
      expect(response.body).to include('Diamine')
    end

    it 'does not include active entries' do
      create(:collected_ink, user: user, brand_name: 'Diamine', archived_on: nil)
      get :index
      expect(response).to be_successful
      expect(response.body).to_not include('Diamine')
    end
  end

end
