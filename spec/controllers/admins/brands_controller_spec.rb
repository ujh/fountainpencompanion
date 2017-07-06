require 'rails_helper'

describe Admins::BrandsController do

  fixtures :collected_inks, :admins

  let(:admin) { admins(:urban) }

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  describe '#show' do
    it 'requires authentication' do
      get :show, params: { id: 'Diamine' }
      expect(response).to redirect_to(new_admin_session_path)
    end
  end

end
