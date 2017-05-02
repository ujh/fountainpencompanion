require 'rails_helper'

describe InksController do

  render_views

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
