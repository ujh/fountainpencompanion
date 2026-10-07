require "rails_helper"

describe "GET /up" do
  it "responds with 200 without authentication" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
