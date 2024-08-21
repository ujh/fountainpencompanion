require "rails_helper"

describe Admins::Pens::BrandClustersController do
  let(:admin) { create(:user, :admin) }

  describe "#new" do
    it "requires authentication" do
      get "/admins/pens/brand_clusters/new"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders the page" do
        create(:pens_model)
        get "/admins/pens/brand_clusters/new"
        expect(response).to be_successful
      end
    end
  end

  describe "#create" do
    let(:model) { create(:pens_model) }

    it "requires authentication" do
      post "/admins/pens/brand_clusters?model_id=#{model.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "creates the new brand" do
        expect do
          post "/admins/pens/brand_clusters?model_id=#{model.id}"
        end.to change(Pens::Brand, :count).by(1)
      end
    end
  end

  describe "#update" do
    let(:brand) { create(:pens_brand) }
    let(:old_brand) { create(:pens_brand) }
    let(:model) { create(:pens_model, pen_brand: old_brand) }

    it "requires authentication" do
      put "/admins/pens/brand_clusters/#{model.id}?brand_id=#{brand.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "updates the brand" do
        expect do
          put "/admins/pens/brand_clusters/#{model.id}?brand_id=#{brand.id}"
        end.to change { model.reload.pen_brand }.from(old_brand).to(brand)
      end
    end
  end
end
