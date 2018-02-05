require 'rails_helper'

describe CollectedPensController do
  fixtures :collected_pens, :users
  render_views

  let(:user) { users(:moni) }

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(user)
      end

      it 'renders the users pens' do
        get :index
        ws = collected_pens(:monis_wing_sung)
        expect(response).to be_successful
        expect(response.body).to include(ws.brand)
        expect(response.body).to include(ws.model)
      end
    end
  end
end
