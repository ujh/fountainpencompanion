require "rails_helper"

describe PagesController do
  it "renders a 404 when the page does not exist" do
    get :show, params: { id: "doesnotexists" }
    expect(response).to have_http_status(:not_found)
  end

  it "renders a 404 for partials" do
    get :show, params: { id: "_leaderboard_row" }
    expect(response).to have_http_status(:not_found)
  end

  it "renders a 404 for paths outside the pages directory" do
    get :show, params: { id: "../layouts/application" }
    expect(response).to have_http_status(:not_found)
  end

  it "has an entry for every page template" do
    templates =
      Dir[Rails.root.join("app/views/pages/[^_]*")].map { |f| File.basename(f).split(".").first }
    expect(described_class::PAGES).to match_array(templates)
  end

  it "redirects to the dashboard when page is home and user is logged in" do
    sign_in(create(:user))
    get :show, params: { id: "home" }
    expect(response).to redirect_to(dashboard_path)
  end
end
