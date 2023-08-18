require "rails_helper"

describe DescriptionsController do
  describe "#missing" do
    it "shows inks with missing descriptions" do
      macro_cluster1 = create(:macro_cluster)
      micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
      create(:collected_ink, micro_cluster: micro_cluster1)
      macro_cluster2 = create(:macro_cluster, description: "description")
      micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)
      create(:collected_ink, micro_cluster: micro_cluster2)
      get "/descriptions/missing"
      expect(response.body).to include(macro_cluster1.name)
      expect(response.body).to_not include(macro_cluster2.name)
    end

    it "shows brands with missing descriptions" do
      brand_cluster1 = create(:brand_cluster)
      macro_cluster1 = create(:macro_cluster, brand_cluster: brand_cluster1)
      micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
      create(:collected_ink, micro_cluster: micro_cluster1)
      brand_cluster2 = create(:brand_cluster, description: "description")
      macro_cluster2 = create(:macro_cluster, brand_cluster: brand_cluster2)
      micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)
      create(:collected_ink, micro_cluster: micro_cluster2)
      get "/descriptions/missing"
      expect(response.body).to include(brand_cluster1.name)
      expect(response.body).to_not include(brand_cluster2.name)
    end
  end

  describe "#my_missing" do
    it "requires authentication" do
      get "/descriptions/my_missing"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      let(:user) { create(:user, name: "the name") }

      before(:each) { sign_in(user) }

      it "shows inks of user with missing reviews" do
        macro_cluster1 = create(:macro_cluster)
        micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
        create(:collected_ink, micro_cluster: micro_cluster1, user: user)
        macro_cluster2 = create(:macro_cluster)
        micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)
        create(:collected_ink, micro_cluster: micro_cluster2)
        get "/descriptions/my_missing"
        expect(response.body).to include(macro_cluster1.name)
        expect(response.body).to_not include(macro_cluster2.name)
      end

      it "shows brands of user with missing reviews" do
        brand_cluster1 = create(:brand_cluster)
        macro_cluster1 = create(:macro_cluster, brand_cluster: brand_cluster1)
        micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
        create(:collected_ink, micro_cluster: micro_cluster1, user: user)
        brand_cluster2 = create(:brand_cluster)
        macro_cluster2 = create(:macro_cluster, brand_cluster: brand_cluster2)
        micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)
        create(:collected_ink, micro_cluster: micro_cluster2)
        get "/descriptions/my_missing"
        expect(response.body).to include(brand_cluster1.name)
        expect(response.body).to_not include(brand_cluster2.name)
      end
    end
  end
end
