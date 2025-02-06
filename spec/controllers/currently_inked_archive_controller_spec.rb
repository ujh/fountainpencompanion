require "rails_helper"

describe CurrentlyInkedArchiveController do
  render_views

  let(:user) { create(:user) }
  let(:collected_pen) { create(:collected_pen, user: user) }
  let(:collected_ink) { create(:collected_ink, user: user) }

  let!(:currently_inked) do
    user.currently_inkeds.create!(
      collected_ink: collected_ink,
      collected_pen: collected_pen,
      archived_on: Date.today
    )
  end

  describe "#index" do
    it "requires authentication" do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "renders the currently inkeds" do
        get :index
        expect(response).to be_successful
        expect(response.body).to include(collected_pen.name)
        expect(response.body).to include(collected_ink.name)
      end
    end
  end

  describe "#unarchive" do
    it "requires authentication" do
      post :unarchive, params: { id: currently_inked.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "unarchives the entry" do
        post :unarchive, params: { id: currently_inked.id }
        expect(response).to redirect_to(currently_inked_archive_index_path)
        currently_inked.reload
        expect(currently_inked).to_not be_archived
      end
    end
  end

  describe "#edit" do
    it "requires authentication" do
      get :edit, params: { id: currently_inked.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "renders correctly" do
        get :edit, params: { id: currently_inked.id }
        expect(response).to be_successful
        expect(response).to render_template(:edit)
      end
    end
  end

  describe "#update" do
    let(:new_collected_ink) do
      create(:collected_ink, brand_name: "Robert Oster", ink_name: "Fire and Ice", user: user)
    end

    it "requires authentication" do
      expect do
        put :update,
            params: {
              id: currently_inked.id,
              currently_inked: {
                collected_ink_id: new_collected_ink.id
              }
            }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { collected_pen.reload }
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "updates the data" do
        expect do
          put :update,
              params: {
                id: currently_inked.id,
                currently_inked: {
                  collected_ink_id: new_collected_ink.id
                }
              }
          expect(response).to redirect_to(currently_inked_archive_index_path)
        end.to change { currently_inked.reload.collected_ink }.from(collected_ink).to(
          new_collected_ink
        )
      end

      it "renders the index when invalid" do
        expect do
          put :update, params: { id: currently_inked.id, currently_inked: { collected_ink_id: -1 } }
        end.to_not change { currently_inked.reload.collected_ink_id }
        expect(response).to be_successful
        expect(response).to render_template(:edit)
      end
    end
  end

  describe "#destroy" do
    it "requires authentication" do
      delete :destroy, params: { id: currently_inked.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "deletes the entry" do
        expect do
          delete :destroy, params: { id: currently_inked.id }
          expect(response).to redirect_to(currently_inked_archive_index_path)
        end.to change { CurrentlyInked.count }.by(-1)
      end

      it "does not delete data from other users" do
        other_user = create(:user)
        other_currently_inked =
          other_user.currently_inkeds.create!(
            collected_ink: create(:collected_ink, user: other_user),
            collected_pen: create(:collected_pen, user: other_user)
          )
        expect do
          expect do delete :destroy, params: { id: other_currently_inked.id } end.to raise_error(
            ActiveRecord::RecordNotFound
          )
        end.to_not change { CurrentlyInked.count }
      end
    end
  end
end
