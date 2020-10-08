require 'rails_helper'

describe UsersController do
  describe '#index' do
    it 'includes confirmed users' do
      user = create(:user, name: 'the name')
      get '/users'
      expect(response).to be_successful
      expect(response.body).to include('the name')
      expect(response.body).to include("/users/#{user.id}")
    end

    it 'does not include users that have no user name' do
      user = create(:user, name: '')
      get '/users'
      expect(response).to be_successful
      expect(response.body).to_not include("/users/#{user.id}")
    end
  end
end
