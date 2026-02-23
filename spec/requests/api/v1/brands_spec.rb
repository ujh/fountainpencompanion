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

  describe "GET /show" do
    it "requires authentication" do
      brand = create(:brand_cluster)
      get "/api/v1/brands/#{brand.id}", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "returns the brand details" do
        brand = create(:brand_cluster, name: "Diamine", description: "A popular ink brand")
        get "/api/v1/brands/#{brand.id}", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json).to include(
          data:
            hash_including(
              id: brand.id.to_s,
              type: "brand_cluster",
              attributes:
                hash_including(
                  name: "Diamine",
                  description: "A popular ink brand",
                  public_ink_count: 0
                )
            )
        )
      end

      it "includes macro_clusters relationship" do
        brand = create(:brand_cluster, name: "Diamine")
        macro_cluster = create(:macro_cluster, brand_cluster: brand)

        get "/api/v1/brands/#{brand.id}", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json[:data][:relationships][:macro_clusters][:data]).to contain_exactly(
          hash_including(id: macro_cluster.id.to_s, type: "macro_cluster")
        )
      end

      it "includes macro_clusters in the included section" do
        brand = create(:brand_cluster, name: "Diamine")
        macro_cluster =
          create(:macro_cluster, brand_cluster: brand, brand_name: "Diamine", ink_name: "Oxblood")

        get "/api/v1/brands/#{brand.id}", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json[:included]).to contain_exactly(
          hash_including(id: macro_cluster.id.to_s, type: "macro_cluster")
        )
      end

      it "returns 404 for non-existent brand" do
        get "/api/v1/brands/999999", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
