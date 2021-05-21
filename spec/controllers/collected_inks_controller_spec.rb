require 'rails_helper'

describe CollectedInksController do

  render_views

  let(:user) { create(:user) }

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      let(:user_inks) do
        [
          create(:collected_ink, user: user, ink_name: 'Marine'),
          create(:collected_ink, user: user, ink_name: 'Syrah'),
          create(:collected_ink, user: user, brand_name: 'Robert Oster', ink_name: 'Fire and Ice')
        ]
      end
      let(:other_inks) do
        [
          create(:collected_ink, ink_name: 'Pumpkin'),
          create(:collected_ink, ink_name: 'Twilight'),
          create(:collected_ink, brand_name: 'Robert Oster', ink_name: 'Peppermint')
        ]
      end

      before do
        sign_in(user)
        user_inks
        other_inks
      end

      it 'renders the ink index page' do
        get :index
        expect(response).to be_successful
      end

      it 'renders the CSV' do
        get :index, format: "csv"
        expect(response).to be_successful
        expected_csv = CSV.generate(col_sep: ";") do |csv|
          csv << [
            "Brand",
            "Line",
            "Name",
            "Type",
            "Color",
            "Swabbed",
            "Used",
            "Comment",
            "Private Comment",
            "Archived",
            "Usage"
          ]
          user_inks.each do |ci|
            csv << [
              ci.brand_name,
              ci.line_name,
              ci.ink_name,
              ci.kind,
              ci.color,
              ci.swabbed,
              ci.used,
              ci.comment,
              ci.private_comment,
              ci.archived?,
              ci.currently_inkeds.count
            ]
          end
        end
        expect(response.body).to eq(expected_csv)
      end

      it 'renders the JSON' do
        get :index, format: :json
        expect(response).to be_successful
        expect(response.body).to include(user_inks.first.ink_name)
        expect(response.body).to include(user_inks.first.brand_name)
      end
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
          expect(response).to redirect_to(collected_inks_path)
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
          expect(response).to redirect_to(collected_inks_path)
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
          expect(response).to redirect_to(collected_inks_path)
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
          expect(response).to redirect_to(collected_inks_path(search: { archive: true }))
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
        expect(response).to redirect_to(collected_inks_path)
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
          expect(response).to redirect_to(collected_inks_path)
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

      it 'strips out spaces from colour field' do
        expect do
          post :create, params: { collected_ink: { brand_name: 'brand', ink_name: 'ink', color: '#000000 '} }
          expect(response).to redirect_to(collected_inks_path)
        end.to change { user.collected_inks.count }.by(1)
      end

      it 'renders a validation error when colour too long' do
        expect do
          post :create, params: { collected_ink: { brand_name: 'brand', ink_name: 'ink', color: 'turquoise blue'} }
          expect(response).to render_template(:new)
        end.to_not change { user.collected_inks.count }
      end
    end
  end
end
