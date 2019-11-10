require 'rails_helper'

describe CollectedInks::BetaArchiveController do
  render_views

  let(:user) { create(:user) }

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'signed in' do
    before do
      sign_in(user)
    end

    it 'renders the ink index page' do
      create(:collected_ink, user: user, brand_name: 'Diamine', archived_on: Date.today)
      get :index
      expect(response).to be_successful
      expect(response.body).to include('Diamine')
    end

    it 'does not include active entries' do
      create(:collected_ink, user: user, brand_name: 'Diamine', archived_on: nil)
      get :index
      expect(response).to be_successful
      expect(response.body).to_not include('Diamine')
    end
  end

  describe '#destroy' do

    it 'requires authentication' do
      delete :destroy, params: { id: 1 }
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      before do
        sign_in(user)
      end

      it 'deletes the collected ink' do
        ink = create(:collected_ink, user: user)
        expect do
          delete :destroy, params: { id: ink.id }
          expect(response).to redirect_to(collected_inks_beta_archive_index_path)
        end.to change { user.collected_inks.count }.by(-1)
      end

      it 'does not delete inks from other users' do
        ink = create(:collected_ink)
        expect do
          delete :destroy, params: { id: ink.id }
          expect(response).to redirect_to(collected_inks_beta_archive_index_path)
        end.to_not change { user.collected_inks.count }
      end

      it 'does not delete inks that have currently inkeds' do
        ink = create(:collected_ink, user: user, currently_inked_count: 1)
        expect do
          delete :destroy, params: { id: ink.id }
          expect(response).to redirect_to(collected_inks_beta_archive_index_path)
        end.to_not change { user.collected_inks.count }
      end
    end
  end

  describe '#unarchive' do

    it 'requires authentication' do
      post :unarchive, params: { id: 1 }
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      before do
        sign_in(user)
      end

      it 'unarchives the ink' do
        ink = create(:collected_ink, user: user, archived_on: Date.today)
        expect do
          post :unarchive, params: { id: ink.id }
          expect(response).to redirect_to(collected_inks_beta_archive_index_path)
        end.to change { ink.reload.archived_on }.from(Date.today).to(nil)
      end

      it 'does not archive other user inks' do
        ink = create(:collected_ink, archived_on: Date.today)
        expect do
          post :unarchive, params: { id: ink.id }
          expect(response).to redirect_to(collected_inks_beta_archive_index_path)
        end.to_not change { ink.reload.archived_on }
      end
    end

  end
end
