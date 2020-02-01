require 'rails_helper'

describe CollectedInks::BetaController do
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
      create(:collected_ink, user: user, brand_name: 'Diamine')
      get :index
      expect(response).to be_successful
      expect(response.body).to include('Diamine')
    end

    it 'does not include archived entries' do
      create(:collected_ink, user: user, brand_name: 'Diamine', archived_on: Date.today)
      get :index
      expect(response).to be_successful
      expect(response.body).to_not include('Diamine')
    end

    context 'only archived entries' do

      it 'renders only archived entries' do
        create(:collected_ink, user: user, brand_name: 'Diamine', archived_on: Date.today)
        get :index, params: { search: { archive: 'true' } }
        expect(response).to be_successful
        expect(response.body).to include('Diamine')
      end

      it 'does not include active entries' do
        create(:collected_ink, user: user, brand_name: 'Diamine')
        get :index, params: { search: { archive: 'true' } }
        expect(response).to be_successful
        expect(response.body).to_not include('Diamine')
      end
    end

    it 'renders the CSV' do
      create(:collected_ink, user: user, brand_name: 'Diamine', ink_name: 'Meadow')
      create(:collected_ink, user: user, brand_name: 'Diamine', ink_name: 'Oxford Blue', archived_on: Date.today)
      get :index, format: 'csv'
      expect(response).to be_successful
      expect(response.body).to include('Meadow')
      expect(response.body).to include('Oxford Blue')
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
          expect(response).to redirect_to(collected_inks_beta_index_path)
        end.to change { user.collected_inks.count }.by(-1)
      end

      it 'does not delete inks from other users' do
        ink = create(:collected_ink)
        expect do
          expect do
            delete :destroy, params: { id: ink.id }
          end.to raise_error(ActiveRecord::RecordNotFound)
        end.to_not change { user.collected_inks.count }
      end

      it 'does not delete inks that have currently inkeds' do
        ink = create(:collected_ink, user: user, currently_inked_count: 1)
        expect do
          delete :destroy, params: { id: ink.id }
          expect(response).to redirect_to(collected_inks_beta_index_path)
        end.to_not change { user.collected_inks.count }
      end
    end
  end

  describe '#archive' do

    it 'requires authentication' do
      post :archive, params: { id: 1 }
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      before do
        sign_in(user)
      end

      it 'archives the ink' do
        ink = create(:collected_ink, user: user)
        expect do
          post :archive, params: { id: ink.id }
          expect(response).to redirect_to(collected_inks_beta_index_path)
        end.to change { ink.reload.archived_on }.from(nil).to(Date.today)
      end

      it 'does not archive other user inks' do
        ink = create(:collected_ink)
        expect do
          expect do
            post :archive, params: { id: ink.id }
          end.to raise_error(ActiveRecord::RecordNotFound)
        end.to_not change { ink.reload.archived_on }
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
          expect(response).to redirect_to(collected_inks_beta_index_path)
        end.to change { ink.reload.archived_on }.from(Date.today).to(nil)
      end

      it 'does not archive other user inks' do
        ink = create(:collected_ink, archived_on: Date.today)
        expect do
          expect do
            post :unarchive, params: { id: ink.id }
          end.to raise_error(ActiveRecord::RecordNotFound)
        end.to_not change { ink.reload.archived_on }
      end
    end
  end

  describe '#edit' do

    it 'requires authentication' do
      get :edit, params: { id: 1 }
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      before do
        sign_in(user)
      end

      it 'renders the edit page' do
        ink = create(:collected_ink, user: user)
        get :edit, params: { id: ink.id }
        expect(response).to be_successful
      end
    end
  end

  describe '#update' do

    it 'requires authentication' do
      put :update, params: { id: 1 }
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      before do
        sign_in(user)
      end

      it 'renders the edit page' do
        ink = create(:collected_ink, user: user, swabbed: false, used: false)
        put :update, params: { id: ink.id, collected_ink: {
          brand_name: 'new brand name',
          line_name: 'new line name',
          ink_name: 'new ink name',
          maker: 'new maker',
          kind: 'sample',
          swabbed: true,
          used: true,
          comment: 'new comment',
          color: '#000000',
          private: true,
        } }
        expect(response).to redirect_to(collected_inks_beta_index_path)
        ink.reload
        expect(ink.brand_name).to eq('new brand name')
        expect(ink.line_name).to eq('new line name')
        expect(ink.ink_name).to eq('new ink name')
        expect(ink.maker).to eq('new maker')
        expect(ink.kind).to eq('sample')
        expect(ink.swabbed).to eq(true)
        expect(ink.used).to eq(true)
        expect(ink.comment).to eq('new comment')
        expect(ink.color).to eq('#000000')
        expect(ink).to be_private
      end

      it 'renders edit on validation error' do
        ink = create(:collected_ink, user: user)
        put :update, params: { id: ink.id, collected_ink: { brand_name: ''} }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe '#new' do
    it 'requires authentication' do
      get :new
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      before do
        sign_in(user)
      end

      it 'renders the edit page' do
        get :new
        expect(response).to be_successful
      end
    end
  end

  describe '#create' do

    it 'requires authentication' do
      post :create
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      before do
        sign_in(user)
      end

      it 'creates a new entry' do
        expect do
          post :create, params: { collected_ink: { brand_name: 'brand', ink_name: 'ink'} }
          expect(response).to redirect_to(collected_inks_beta_index_path)
        end.to change { user.collected_inks.count }.by(1)
      end

      it 'renders new when validation error' do
        expect do
          post :create, params: { collected_ink: { brand_name: 'brand'} }
          expect(response).to render_template(:new)
        end.to_not change { user.collected_inks.count }
      end

      it 'renders a validation error when the colour has an invalid format' do
        expect do
          post :create, params: { collected_ink: { brand_name: 'brand', ink_name: 'ink', color: 'green'} }
          expect(response).to render_template(:new)
        end.to_not change { user.collected_inks.count }
      end
    end
  end
end
