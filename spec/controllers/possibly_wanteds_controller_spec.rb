require 'rails_helper'

RSpec.describe PossiblyWantedsController do
  let(:user) { create(:user) }

  describe '#show' do
    it 'requires authentication' do
      get :show, params: { user_id: user.id }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

end
