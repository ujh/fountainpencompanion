require "rails_helper"

describe FriendshipsController do
  let(:user) { create(:user) }
  let(:friend) { create(:user) }

  describe "#create" do
    it "requires authentication" do
      post :create, params: { friend_id: friend.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "creates a new friend request" do
        expect do
          post :create, params: { friend_id: friend.id }
          expect(response).to be_successful
        end.to change { Friendship.count }.by(1)
        friendship = Friendship.last
        expect(friendship.sender).to eq(user)
        expect(friendship.friend).to eq(friend)
        expect(friendship.approved).to eq(false)
      end

      it "does not create a friend request when already sent" do
        create(:friendship, sender: user, friend: friend, approved: false)
        expect do
          post :create, params: { friend_id: friend.id }
          expect(response).to have_http_status(:bad_request)
        end.to_not change { Friendship.count }
      end

      it "does not create a friend request when already sent by other user" do
        create(:friendship, sender: friend, friend: user, approved: false)
        expect do
          post :create, params: { friend_id: friend.id }
          expect(response).to have_http_status(:bad_request)
        end.to_not change { Friendship.count }
      end

      it "does not create a friend request when using own user id" do
        expect do
          post :create, params: { friend_id: user.id }
          expect(response).to have_http_status(:bad_request)
        end.to_not change { Friendship.count }
      end
    end
  end

  describe "#update" do
    it "requires authentication" do
      put :update, params: { id: friend.id, approved: "true" }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "approves the friend request received by other user" do
        friendship = create(:friendship, sender: friend, friend: user)
        put :update, params: { id: friend.id, approved: "true" }
        expect(response).to be_successful
        expect(friendship.reload).to be_approved
      end

      it "does not approve friend request sent to other user" do
        friendship = create(:friendship, sender: user, friend: friend)
        put :update, params: { id: friend.id, approved: "true" }
        expect(response).to have_http_status(:bad_request)
        expect(friendship.reload).to_not be_approved
      end

      it "does not approve other users friend requests" do
        friendship = create(:friendship)
        put :update, params: { id: -1, approved: "true" }
        expect(response).to have_http_status(:bad_request)
        expect(friendship.reload).to_not be_approved
      end
    end
  end

  describe "#destroy" do
    it "requires authentication" do
      delete :destroy, params: { id: friend.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "destroys the friend request if sent" do
        friendship = create(:friendship, sender: user, friend: friend)
        expect do
          delete :destroy, params: { id: friend.id }
          expect(response).to be_successful
        end.to change { Friendship.count }.by(-1)
      end

      it "destroys the friend request if received" do
        friendship = create(:friendship, sender: friend, friend: user)
        expect do
          delete :destroy, params: { id: friend.id }
          expect(response).to be_successful
        end.to change { Friendship.count }.by(-1)
      end

      it "does not destroy other users friend requests" do
        friendship = create(:friendship)
        expect do
          delete :destroy, params: { id: -1 }
          expect(response).to have_http_status(:bad_request)
        end.to_not change { Friendship.count }
      end
    end
  end
end
