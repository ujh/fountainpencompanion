require 'rails_helper'

describe Admins::UsersController do

  fixtures :admins

  let(:admin) { admins(:urban) }
  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_admin_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'renders' do
        get :index
        expect(response).to be_successful
      end
    end
  end
end
