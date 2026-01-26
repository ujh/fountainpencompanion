require "rails_helper"

describe AuthenticationTokensController do
  render_views

  let(:user) { create(:user) }

  describe "#index" do
    it "requires authentication" do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before { sign_in(user) }

      it "renders the index page" do
        get :index
        expect(response).to be_successful
      end

      it "shows only the current user's tokens" do
        user_token = create(:authentication_token, user: user, name: "My Token")
        other_token = create(:authentication_token, name: "Other Token")

        get :index

        expect(assigns(:tokens)).to include(user_token)
        expect(assigns(:tokens)).not_to include(other_token)
      end
    end
  end

  describe "#create" do
    it "requires authentication" do
      post :create, params: { authentication_token: { name: "Test" } }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before { sign_in(user) }

      it "creates a new token with valid params" do
        expect {
          post :create, params: { authentication_token: { name: "My API Token" } }
        }.to change { user.authentication_tokens.count }.by(1)
      end

      it "sets the flash with the access token" do
        post :create, params: { authentication_token: { name: "My API Token" } }
        expect(flash[:new_access_token]).to be_present
        expect(flash[:new_access_token]).to match(/^\d+\./)
      end

      it "redirects to index on success" do
        post :create, params: { authentication_token: { name: "My API Token" } }
        expect(response).to redirect_to(authentication_tokens_path)
      end

      it "renders index with errors when name is blank" do
        post :create, params: { authentication_token: { name: "" } }
        expect(response).to render_template(:index)
        expect(assigns(:new_token).errors[:name]).to be_present
      end
    end
  end

  describe "#destroy" do
    let!(:token) { create(:authentication_token, user: user) }

    it "requires authentication" do
      delete :destroy, params: { id: token.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before { sign_in(user) }

      it "deletes the token" do
        expect { delete :destroy, params: { id: token.id } }.to change {
          user.authentication_tokens.count
        }.by(-1)
      end

      it "redirects to index" do
        delete :destroy, params: { id: token.id }
        expect(response).to redirect_to(authentication_tokens_path)
      end

      it "cannot delete another user's token" do
        other_token = create(:authentication_token)
        expect { delete :destroy, params: { id: other_token.id } }.to raise_error(
          ActiveRecord::RecordNotFound
        )
      end
    end
  end
end
