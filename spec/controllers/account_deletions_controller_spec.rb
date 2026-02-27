require "rails_helper"

describe AccountDeletionsController do
  let(:user) { create(:user) }

  describe "#create" do
    it "requires authentication" do
      post :create
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before { sign_in(user) }

      it "sends a deletion confirmation email" do
        expect {
          post :create
          Sidekiq::Worker.drain_all
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "redirects to account path with notice" do
        post :create
        expect(response).to redirect_to(account_path)
        expect(flash[:notice]).to match(/email/)
      end
    end
  end

  describe "#show" do
    it "requires authentication" do
      get :show, params: { token: "invalid" }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before { sign_in(user) }

      it "renders the confirmation page with a valid token" do
        token = user.signed_id(purpose: :account_deletion, expires_in: 24.hours)
        get :show, params: { token: token }
        expect(response).to be_successful
        expect(assigns(:token)).to eq(token)
      end

      it "redirects with alert for an invalid token" do
        get :show, params: { token: "invalid" }
        expect(response).to redirect_to(account_path)
        expect(flash[:alert]).to match(/Invalid/)
      end

      it "redirects with alert for another user's token" do
        other_user = create(:user)
        token = other_user.signed_id(purpose: :account_deletion, expires_in: 24.hours)
        get :show, params: { token: token }
        expect(response).to redirect_to(account_path)
        expect(flash[:alert]).to match(/Invalid/)
      end
    end
  end

  describe "#destroy" do
    it "requires authentication" do
      delete :destroy, params: { token: "invalid" }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before { sign_in(user) }

      it "sets deletion_requested_at and queues deletion job with a valid token" do
        token = user.signed_id(purpose: :account_deletion, expires_in: 24.hours)
        delete :destroy, params: { token: token }

        user.reload
        expect(user.deletion_requested_at).to be_present
        expect(CleanUp::DeleteUser.jobs.size).to eq(1)
      end

      it "signs out the user and redirects to root" do
        token = user.signed_id(purpose: :account_deletion, expires_in: 24.hours)
        delete :destroy, params: { token: token }

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to match(/scheduled for deletion/)
        expect(controller.current_user).to be_nil
      end

      it "redirects with alert for an invalid token" do
        delete :destroy, params: { token: "invalid" }
        expect(response).to redirect_to(account_path)
        expect(flash[:alert]).to match(/Invalid/)
      end

      it "redirects with alert for another user's token" do
        other_user = create(:user)
        token = other_user.signed_id(purpose: :account_deletion, expires_in: 24.hours)
        delete :destroy, params: { token: token }
        expect(response).to redirect_to(account_path)
        expect(flash[:alert]).to match(/Invalid/)
      end
    end
  end
end
