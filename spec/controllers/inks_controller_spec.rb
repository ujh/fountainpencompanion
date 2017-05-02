require 'rails_helper'

describe InksController do

  render_views

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      let!(:user) do
        user = User.new(email: 'test@example.com')
        user.password = user.password_confirmation = 'password'
        user.save!
        user
      end
      let!(:manufacturer) { Manufacturer.create!(name: 'manufacturer') }
      let!(:ink) { Ink.create!(name: 'ink', manufacturer: manufacturer) }
      let!(:collected_ink) { CollectedInk.create!(user: user, ink: ink) }

      before(:each) do
        sign_in(user)
      end

      it 'renders the ink index page' do
        get :index
        expect(response).to be_successful
        expect(response.body).to include(manufacturer.name)
        expect(response.body).to include(ink.name)
      end
    end
  end
end
