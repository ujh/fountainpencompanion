require "rails_helper"
require "apipie/rspec/response_validation_helper"

describe Api::V1::CurrentlyInkedController do
  let(:user) { create(:user) }

  describe "#index" do
    it "requires authentication" do
      get :index, format: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context "signed in" do
      auto_validate_rendered_views

      let!(:currently_inked) { create(:currently_inked, user: user) }

      before(:each) { sign_in(user) }

      it "returns the user's currently inked pens and inks" do
        get :index, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["data"].length).to eq(1)
        expect(json_response["data"][0]["id"].to_i).to eq(currently_inked.id)
      end
    end
  end
end
