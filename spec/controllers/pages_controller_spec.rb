require "rails_helper"

describe PagesController do
  it "renders a 404 when the page does not exist" do
    get :show, params: { id: "doesnotexists" }
    expect(response).to have_http_status(:not_found)
  end

  it "redirects to the dashboard when page is home and user is logged in" do
    sign_in(create(:user))
    get :show, params: { id: "home" }
    expect(response).to redirect_to(dashboard_path)
  end
end
