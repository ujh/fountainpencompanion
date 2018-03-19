require 'rails_helper'

describe CurrentlyInkedController do

  render_views

  fixtures :collected_inks, :collected_pens, :users

  let(:user) { users(:moni) }
  let(:collected_pen) { collected_pens(:monis_wing_sung) }
  let(:collected_ink) { collected_inks(:monis_marine) }

  describe '#index' do

    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      let!(:currently_inked) do
        user.currently_inkeds.create!(
          collected_ink: collected_ink,
          collected_pen: collected_pen
        )
      end

      it 'renders the currently inkeds' do
        get :index
        expect(response).to be_successful
        expect(response.body).to include(collected_pen.name)
        expect(response.body).to include(collected_ink.name)
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

    end

  end

  describe '#update' do

    let!(:currently_inked) do
      user.currently_inkeds.create!(
        collected_ink: collected_ink,
        collected_pen: collected_pen
      )
    end

    it 'requires authentication' do
      expect do
        put :update, params: { id: currently_inked.id, currently_inked: {
          collected_ink_id: collected_inks(:monis_fire_and_ice)
        }}
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { collected_pen.reload }
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      let(:new_collected_ink) { collected_inks(:monis_fire_and_ice) }
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
        currently_inked = users(:tom).currently_inkeds.create!(
          collected_ink: collected_inks(:toms_marine),
          collected_pen: collected_pens(:toms_platinum)
        )
        expect do
          delete :destroy, params: { id: currently_inked.id }
          expect(response).to redirect_to(currently_inked_index_path)
        end.to_not change { CurrentlyInked.count }
      end

    end

  end

end
