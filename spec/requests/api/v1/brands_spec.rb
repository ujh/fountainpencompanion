require "rails_helper"

RSpec.describe "Api::V1::Brands", type: :request do
  describe "GET /index" do
    it "requires authentication" do
      get "/api/v1/brands", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "returns all brands in alphabetical order" do
        create(:brand_cluster, name: "Diamine")
        create(:brand_cluster, name: "Robert Oster")
        create(:brand_cluster, name: "Abraxas")

        get "/api/v1/brands", headers: { "ACCEPT" => "application/json" }
        expect(json).to match(
          data: [
            hash_including(attributes: { name: "Abraxas" }),
            hash_including(attributes: { name: "Diamine" }),
            hash_including(attributes: { name: "Robert Oster" })
          ]
        )
      end

      it "returns lines matching the search term" do
        create(:brand_cluster, name: "Diamine")
        create(:brand_cluster, name: "Robert Oster")

        get "/api/v1/brands", params: { term: "rob" }, headers: { "ACCEPT" => "application/json" }

        expect(json).to match(data: [hash_including(attributes: { name: "Robert Oster" })])
      end
    end
  end
end
