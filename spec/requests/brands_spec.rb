require "rails_helper"

describe "Brands" do
  describe "GET /brands" do
    def add_ink(brand_cluster, private: false)
      macro_cluster = create(:macro_cluster, brand_cluster: brand_cluster)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
      create(:collected_ink, micro_cluster: micro_cluster, private: private)
    end

    it "lists the brands with public inks sorted by name with their count" do
      pelikan = create(:brand_cluster, name: "Pelikan")
      diamine = create(:brand_cluster, name: "Diamine")
      hidden = create(:brand_cluster, name: "Hidden Brand")
      add_ink(pelikan)
      add_ink(diamine)
      add_ink(hidden, private: true)
      MacroClusterPopularity.refresh

      get "/brands"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("2 brands")
      expect(response.body.index("Diamine")).to be < response.body.index("Pelikan")
      expect(response.body).not_to include("Hidden Brand")
    end
  end
end
