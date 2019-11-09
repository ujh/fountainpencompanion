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
      get :index
      expect(response).to be_successful
    end
  end
end
