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
