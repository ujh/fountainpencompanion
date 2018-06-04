require 'rails_helper'

describe AccountsController do

  render_views

  describe '#show' do

    it 'requires authentication' do
      get :show
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do

      let(:user) { create(:user) }

      before(:each) do
        sign_in(user)
      end

      it 'renders a page' do
        get :show
        expect(response).to be_successful
      end
    end
  end
end
