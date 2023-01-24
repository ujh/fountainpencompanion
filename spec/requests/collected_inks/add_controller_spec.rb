require "rails_helper"

describe CollectedInks::AddController do
  describe "#create" do
    let(:macro_cluster) { create(:macro_cluster) }

    it "requires authentication" do
      post "/collected_inks/add.json?macro_cluster_id=#{macro_cluster.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    context "signed in" do
      let(:user) { create(:user) }
      before { sign_in(user) }

      it "adds the ink to the user" do
        expect do
          post "/collected_inks/add.json?macro_cluster_id=#{macro_cluster.id}&kind=bottle"
          expect(response).to have_http_status(:created)
        end.to change { user.collected_inks.count }.by(1)
        ink = user.collected_inks.last
        expect(ink.brand_name).to eq(macro_cluster.brand_name)
        expect(ink.line_name).to eq(macro_cluster.line_name)
        expect(ink.ink_name).to eq(macro_cluster.ink_name)
        expect(ink.kind).to eq("bottle")
      end

      it "only adds the ink once" do
        expect do
          post "/collected_inks/add.json?macro_cluster_id=#{macro_cluster.id}&kind=bottle"
          post "/collected_inks/add.json?macro_cluster_id=#{macro_cluster.id}&kind=bottle"
          expect(response).to have_http_status(:created)
        end.to change { user.collected_inks.count }.by(1)
      end
    end
  end
end
