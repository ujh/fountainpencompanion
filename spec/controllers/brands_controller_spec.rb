require "rails_helper"

describe BrandsController do
  render_views

  let(:brand) { create(:brand_cluster) }
  let(:user) { create(:user) }

  describe "#edit" do
    it "requires authentication" do
      get :edit, params: { id: brand.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "renders successfully" do
        get :edit, params: { id: brand.id }
        expect(response).to be_successful
      end
    end
  end

  describe "#update" do
    it "requires authentication" do
      put :update, params: { id: brand.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "updates successfully" do
        put :update, params: { id: brand.id, brand_cluster: { description: "description" } }
        expect(response).to redirect_to(brand_path(brand))
      end

      it "successfully sets the description" do
        expect do
          put :update, params: { id: brand.id, brand_cluster: { description: "description" } }
        end.to change { brand.reload.description }.to("description")
      end

      it "sets the user who made the last change" do
        expect do
          put :update, params: { id: brand.id, brand_cluster: { description: "description" } }
        end.to change { brand.reload.versions.last.whodunnit }.to(user.id.to_s)
      end
    end
  end
end
