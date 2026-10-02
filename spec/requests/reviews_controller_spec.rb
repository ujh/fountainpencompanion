require "rails_helper"

describe ReviewsController do
  describe "#missing" do
    it "shows clusters with missing reviews" do
      macro_cluster1 = create(:macro_cluster)
      micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
      create(:collected_ink, micro_cluster: micro_cluster1)
      macro_cluster2 = create(:macro_cluster)
      create(:ink_review, macro_cluster: macro_cluster2)
      micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)
      create(:collected_ink, micro_cluster: micro_cluster2)
      get "/reviews/missing"
      expect(response.body).to include(macro_cluster1.name)
      expect(response.body).to_not include(macro_cluster2.name)
    end

    it "shows clusters whose only review was rejected" do
      macro_cluster = create(:macro_cluster)
      create(:ink_review, macro_cluster: macro_cluster, rejected_at: Time.current)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
      create(:collected_ink, micro_cluster: micro_cluster)
      get "/reviews/missing"
      expect(response.body).to include(macro_cluster.name)
    end

    it "does not show clusters that only have private collected inks" do
      macro_cluster = create(:macro_cluster)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
      create(:collected_ink, micro_cluster: micro_cluster, private: true)
      get "/reviews/missing"
      expect(response.body).to_not include(macro_cluster.name)
    end

    it "paginates the clusters sorted by name" do
      macro_clusters =
        11.times.map do |i|
          macro_cluster = create(:macro_cluster, brand_name: "Brand #{format("%02d", i)}")
          micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
          create(:collected_ink, micro_cluster: micro_cluster)
          macro_cluster
        end
      first, *middle, last = macro_clusters

      get "/reviews/missing"
      expect(response.body).to include(first.name)
      expect(response.body).to_not include(last.name)

      get "/reviews/missing", params: { page: 2 }
      expect(response.body).to include(last.name)
      middle.each { |macro_cluster| expect(response.body).to_not include(macro_cluster.name) }
    end

    it "caches the list of clusters" do
      macro_cluster1 = create(:macro_cluster)
      micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
      create(:collected_ink, micro_cluster: micro_cluster1)
      get "/reviews/missing"

      macro_cluster2 = create(:macro_cluster)
      micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)
      create(:collected_ink, micro_cluster: micro_cluster2)
      get "/reviews/missing"

      expect(response.body).to include(macro_cluster1.name)
      expect(response.body).to_not include(macro_cluster2.name)
    end

    it "shows the percentage of clusters without reviews" do
      create(:macro_cluster)
      create(:ink_review, macro_cluster: create(:macro_cluster))
      get "/reviews/missing"
      expect(response.body).to include("50.00% inks without review")
    end
  end

  describe "#my_missing" do
    it "requires authentication" do
      get "/reviews/my_missing"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      let(:user) { create(:user, name: "the name") }

      before(:each) { sign_in(user) }

      it "shows clusters of user with missing reviews" do
        macro_cluster1 = create(:macro_cluster)
        micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
        create(:collected_ink, micro_cluster: micro_cluster1, user: user)
        macro_cluster2 = create(:macro_cluster)
        micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)
        create(:collected_ink, micro_cluster: micro_cluster2)
        get "/reviews/my_missing"
        expect(response.body).to include(macro_cluster1.name)
        expect(response.body).to_not include(macro_cluster2.name)
      end
    end
  end
end
