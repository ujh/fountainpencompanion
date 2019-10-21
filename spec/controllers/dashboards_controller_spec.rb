require 'rails_helper'

describe DashboardsController do

  describe '#show' do

    it 'requires authentication' do
      get :show
      expect(response).to redirect_to(new_user_session_path)
    end

  end

end
