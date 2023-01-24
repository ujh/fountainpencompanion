require "rails_helper"

describe Admins::BrandClustersController do
  let(:admin) { create(:admin) }

  describe "#new" do
    it "requires authentication" do
      get "/admins/brand_clusters/new"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders the page" do
        create(:macro_cluster)
        get "/admins/brand_clusters/new"
        expect(response).to be_successful
      end
    end
  end

  describe "#create" do
    let(:macro_cluster) { create(:macro_cluster) }

    it "requires authentication" do
      post "/admins/brand_clusters?macro_cluster_id=#{macro_cluster.id}"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "creates the new brand cluster" do
        expect do
          post "/admins/brand_clusters?macro_cluster_id=#{macro_cluster.id}"
        end.to change(BrandCluster, :count).by(1)
      end
    end
  end

  describe "#update" do
    let(:brand_cluster) { create(:brand_cluster) }
    let(:old_brand_cluster) { create(:brand_cluster) }
    let(:macro_cluster) do
      create(:macro_cluster, brand_cluster: old_brand_cluster)
    end

    it "requires authentication" do
      put "/admins/brand_clusters/#{macro_cluster.id}?brand_cluster_id=#{brand_cluster.id}"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "updates the brand cluster" do
        expect do
          put "/admins/brand_clusters/#{macro_cluster.id}?brand_cluster_id=#{brand_cluster.id}"
        end.to change { macro_cluster.reload.brand_cluster }.from(
          old_brand_cluster
        ).to(brand_cluster)
      end
    end
  end
end
