require 'rails_helper'

describe CurrentlyInkedController do

  render_views

  let(:user) { create(:user) }
  let(:collected_pen) { create(:collected_pen, user: user) }
  let(:collected_ink) { create(:collected_ink, user: user) }

  describe '#index' do

    let!(:currently_inked) do
      user.currently_inkeds.create!(
        collected_ink: collected_ink,
        collected_pen: collected_pen
      )
    end

    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      it 'renders the currently inkeds' do
        get :index
        expect(response).to be_successful
        expect(response.body).to include(collected_pen.name)
        expect(response.body).to include(collected_ink.name)
      end

      it 'exports the csv' do
        get :index, format: :csv
        expect(response).to be_successful
        csv = CSV.generate(col_sep: ";") do |csv|
          csv << ["Pen", "Ink", "Date Inked", "Date Cleaned", "Comment"]
          csv << [
            currently_inked.pen_name,
            currently_inked.ink_name,
            currently_inked.inked_on,
            currently_inked.archived_on,
            currently_inked.comment
          ]
        end
        expect(response.body).to eq(csv)
      end

    end

  end

  describe '#create' do

    it 'requires authentication' do
      expect do
        post :create, params: { currently_inked: {
          collected_ink_id: collected_ink.id,
          collected_pen_id: collected_pen.id
        }}
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { CurrentlyInked.count }
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      it 'creates the data' do
        expect do
          post :create, params: { currently_inked: {
            collected_ink_id: collected_ink.id,
            collected_pen_id: collected_pen.id
          }}
          expect(response).to redirect_to(currently_inked_index_path(anchor: "add-form"))
        end.to change { user.currently_inkeds.count }.by(1)
        currently_inked = user.currently_inkeds.order(:id).last
        expect(currently_inked.collected_ink).to eq(collected_ink)
        expect(currently_inked.collected_pen).to eq(collected_pen)
      end

      it 'renders the index when invalid' do
        expect do
          post :create, params: { currently_inked: {
            collected_ink_id: collected_ink.id,
          } }
          expect(response).to be_successful
          expect(response).to render_template(:index)
        end.to_not change { user.currently_inkeds.count }
      end
    end
  end

  describe '#edit' do
    let!(:currently_inked) do
      user.currently_inkeds.create!(
        collected_ink: collected_ink,
        collected_pen: collected_pen
      )
    end

    it 'requires authentication' do
      get :edit, params: { id: currently_inked.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      it 'renders correctly' do
        get :edit, params: { id: currently_inked.id }
        expect(response).to be_successful
        expect(response).to render_template(:index)
      end
    end
  end

  describe '#refill' do

    let!(:currently_inked) do
      user.currently_inkeds.create!(
        collected_ink: collected_ink,
        collected_pen: collected_pen
      )
    end

    it 'requires authentication' do
      expect do
        post :refill, params: { id: currently_inked.id }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { CurrentlyInked.count }
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      it 'creates a new entry and archives the old one' do
        expect do
          post :refill, params: { id: currently_inked.id }
          expect(response).to redirect_to(currently_inked_index_path)
        end.to change { CurrentlyInked.count }.by(1)
        expect(currently_inked.reload).to be_archived
        newest_ci = CurrentlyInked.last
        expect(newest_ci.collected_ink).to eq(currently_inked.collected_ink)
        expect(newest_ci.collected_pen).to eq(currently_inked.collected_pen)
        expect(newest_ci.inked_on).to eq(Date.today)
      end
    end
  end

  describe '#update' do

    let!(:currently_inked) do
      user.currently_inkeds.create!(
        collected_ink: collected_ink,
        collected_pen: collected_pen
      )
    end
    let(:new_collected_ink) { create(:collected_ink, brand_name: 'Robert Oster', ink_name: 'Fire and Ice', user: user) }

    it 'requires authentication' do
      expect do
        put :update, params: { id: currently_inked.id, currently_inked: {
          collected_ink_id: new_collected_ink.id
        } }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { collected_pen.reload }
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      it 'updates the data' do
        expect do
          put :update, params: { id: currently_inked.id, currently_inked: {
            collected_ink_id: new_collected_ink.id
          }}
          expect(response).to redirect_to(currently_inked_index_path(anchor: currently_inked.id))
        end.to change { currently_inked.reload.collected_ink }.from(collected_ink).to(new_collected_ink)
      end

      it 'updates an archived entry' do
        currently_inked.update(archived_on: Date.today)
        expect do
          put :update, params: { id: currently_inked.id, currently_inked: {
            collected_ink_id: new_collected_ink.id
          }}
          expect(response).to redirect_to(currently_inked_index_path(anchor: currently_inked.id))
        end.to change { currently_inked.reload.collected_ink }.from(collected_ink).to(new_collected_ink)
      end

      it 'renders the index when invalid' do
        expect do
          put :update, params: { id: currently_inked.id, currently_inked: {
            collected_ink_id: -1
          }}
        end.to_not change { currently_inked.reload.collected_ink_id }
        expect(response).to be_successful
        expect(response).to render_template(:index)
      end
    end

  end

  describe '#archive' do
    let!(:currently_inked) do
      user.currently_inkeds.create!(
        collected_ink: collected_ink,
        collected_pen: collected_pen
      )
    end

    it 'requires authentication' do
      post :archive, params: { id: currently_inked.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      it 'archives the ink' do
        post :archive, params: { id: currently_inked.id }
        expect(response).to redirect_to(currently_inked_index_path)
        expect(currently_inked.reload).to be_archived
      end
    end
  end

  describe '#destroy' do

    let!(:currently_inked) do
      user.currently_inkeds.create!(
        collected_ink: collected_ink,
        collected_pen: collected_pen
      )
    end

    it 'requires authentication' do
      expect do
        delete :destroy, params: { id: currently_inked.id }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { CurrentlyInked.count }
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      it 'deletes the entry' do
        expect do
          delete :destroy, params: { id: currently_inked.id }
          expect(response).to redirect_to(currently_inked_index_path)
        end.to change { CurrentlyInked.count }.by(-1)
      end

      it 'deletes an archived entry' do
        currently_inked.update(archived_on: Date.today)
        expect do
          delete :destroy, params: { id: currently_inked.id }
          expect(response).to redirect_to(currently_inked_index_path)
        end.to change { CurrentlyInked.count }.by(-1)
      end

      it 'does not delete data from other users' do
        other_user = create(:user)
        other_currently_inked = other_user.currently_inkeds.create!(
            collected_ink: create(:collected_ink, user: other_user),
            collected_pen: create(:collected_pen, user: other_user)
        )
        expect do
          expect do
            delete :destroy, params: { id: other_currently_inked.id }
          end.to raise_error(ActiveRecord::RecordNotFound)
        end.to_not change { CurrentlyInked.count }
      end

    end

  end

end
