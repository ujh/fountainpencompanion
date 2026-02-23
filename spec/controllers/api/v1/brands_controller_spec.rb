require "rails_helper"
require "apipie/rspec/response_validation_helper"

describe Api::V1::BrandsController do
  let(:user) { create(:user) }

  describe "#index" do
    it "requires authentication" do
      get :index, format: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context "signed in" do
      auto_validate_rendered_views

      let!(:brand) { create(:brand_cluster) }

      before(:each) { sign_in(user) }

      it "returns the user's collected inks" do
        get :index, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["data"].length).to eq(1)
        expect(json_response["data"][0]["id"].to_i).to eq(brand.id)
      end
    end
  end

  describe "#show" do
    it "requires authentication" do
      brand = create(:brand_cluster)
      get :show, params: { id: brand.id }, format: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context "signed in" do
      auto_validate_rendered_views

      let!(:brand) { create(:brand_cluster, name: "Diamine", description: "A popular ink brand") }

      before(:each) { sign_in(user) }

      it "returns the brand details" do
        get :show, params: { id: brand.id }, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["data"]["id"].to_i).to eq(brand.id)
        expect(json_response["data"]["attributes"]["name"]).to eq("Diamine")
        expect(json_response["data"]["attributes"]["description"]).to eq("A popular ink brand")
        expect(json_response["data"]["attributes"]["public_ink_count"]).to eq(0)
      end

      it "includes macro_clusters relationship" do
        macro_cluster = create(:macro_cluster, brand_cluster: brand)
        get :show, params: { id: brand.id }, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        relationship_data = json_response["data"]["relationships"]["macro_clusters"]["data"]
        expect(relationship_data.length).to eq(1)
        expect(relationship_data[0]["id"].to_i).to eq(macro_cluster.id)
        expect(relationship_data[0]["type"]).to eq("macro_cluster")
      end
    end
  end
end
