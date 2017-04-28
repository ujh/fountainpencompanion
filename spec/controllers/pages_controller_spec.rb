require 'rails_helper'

describe PagesController do

  it 'renders a 404 when the page does not exist' do
    get :show, params: { id: 'doesnotexists' }
    expect(response).to have_http_status(:not_found)
  end
end
