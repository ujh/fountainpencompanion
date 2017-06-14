require 'rails_helper'

describe PossiblyWantedsController do

  fixtures :users

  describe '#show' do
    it 'requires authentication' do
      get :show, params: { user_id: users(:moni).id }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

end
