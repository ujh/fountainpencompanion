require 'rails_helper'

describe InksController do

  fixtures :manufacturers, :inks, :users
  render_views

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      let(:user) { users(:moni) }
      let(:manufacturer) { manufacturers(:diamine) }
      let(:ink) { inks(:marine) }
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
