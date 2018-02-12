require 'rails_helper'

describe CurrentlyInkedController do

  render_views

  fixtures :collected_inks, :collected_pens, :users

  let(:user) { users(:moni) }
  let(:collected_pen) { collected_pens(:monis_wing_sung) }
  let(:collected_ink) { collected_inks(:monis_marine) }

  describe '#index' do

    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      let!(:currently_inked) do
        user.currently_inkeds.create!(
          collected_ink: collected_ink,
          collected_pen: collected_pen
        )
      end

      it 'renders the currently inkeds' do
        get :index
        expect(response).to be_successful
        expect(response.body).to include(collected_pen.name)
        expect(response.body).to include(collected_ink.name)
      end

    end

  end

end
