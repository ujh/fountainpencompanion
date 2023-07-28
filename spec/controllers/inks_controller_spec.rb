require "rails_helper"

describe InksController do
  render_views

  let(:brand) { create(:brand_cluster) }
  let(:ink) { create(:macro_cluster, brand_cluster: brand) }
  let(:user) { create(:user) }

  describe "#edit" do
    it "requires authentication" do
      get :edit, params: { id: ink.id, brand_id: brand.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "renders successfully" do
        get :edit, params: { id: ink.id, brand_id: brand.id }
        expect(response).to be_successful
      end
    end
  end

  describe "#update" do
    it "requires authentication" do
      put :update, params: { id: ink.id, brand_id: brand.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "updates successfully" do
        put :update,
            params: {
              id: ink.id,
              brand_id: brand.id,
              macro_cluster: {
                description: "description"
              }
            }
        expect(response).to redirect_to(ink_path(ink))
      end

      it "successfully sets the description" do
        expect do
          put :update,
              params: {
                id: ink.id,
                brand_id: brand.id,
                macro_cluster: {
                  description: "description"
                }
              }
        end.to change { ink.reload.description }.to("description")
      end

      it "sets the user who made the last change" do
        expect do
          put :update,
              params: {
                id: ink.id,
                brand_id: brand.id,
                macro_cluster: {
                  description: "description"
                }
              }
        end.to change { ink.reload.versions.last.whodunnit }.to(user.id.to_s)
      end
    end
  end
end
