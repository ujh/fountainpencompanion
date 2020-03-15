require 'rails_helper'

describe Admins::InkBrandsController do
  let(:admin) { create(:admin) }

  describe '#index' do
    it 'requires authentication' do
      get '/admins/ink_brands'
      expect(response).to redirect_to(new_admin_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'renders' do
        get '/admins/ink_brands'
        expect(response).to be_successful
      end
    end
  end
end
