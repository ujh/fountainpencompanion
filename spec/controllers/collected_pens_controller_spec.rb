require 'rails_helper'

describe CollectedPensController do
  fixtures :collected_pens, :users
  render_views

  let(:user) { users(:moni) }

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(user)
      end

      it 'renders the users pens' do
        get :index
        ws = collected_pens(:monis_wing_sung)
        expect(response).to be_successful
        expect(response.body).to include(ws.brand)
        expect(response.body).to include(ws.model)
      end
    end
  end

  describe '#create' do
    it 'requires authentication' do
      expect do
        post :create, params: { collected_pen: { brand: 'Pelikan', model: 'M205'}}
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { CollectedPen.count }
    end

    context 'signed in' do
      before(:each) do
        sign_in(user)
      end

      it 'creates the data' do
        expect do
          post :create, params: { collected_pen: {
            brand: 'Pelikan',
            model: 'M205'
          }}
          collected_pen = CollectedPen.order(:id).last
          expect(response).to redirect_to(collected_pens_path(anchor: "add-form"))
        end.to change { user.collected_pens.count }.by(1)
        collected_pen = user.collected_pens.order(:id).last
        expect(collected_pen.brand).to eq('Pelikan')
        expect(collected_pen.model).to eq('M205')
      end

      it 'strips out extraneous whitespace' do
        expect do
          post :create, params: { collected_pen: {
            brand: ' Pelikan ',
            model: ' M205 '
          }}
          collected_pen = CollectedPen.order(:id).last
          expect(response).to redirect_to(collected_pens_path(anchor: "add-form"))
        end.to change { user.collected_pens.count }.by(1)
        collected_pen = user.collected_pens.order(:id).last
        expect(collected_pen.brand).to eq('Pelikan')
        expect(collected_pen.model).to eq('M205')
      end
    end
  end

  describe '#update' do

    let(:collected_pen) { collected_pens(:monis_wing_sung) }

    it 'requires authentication' do
      expect do
        put :update, params: { id: collected_pen.id, collected_pen: { brand: 'Not Wing Sung' } }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { collected_pen.reload }
    end

    context 'signed in' do
      before(:each) do
        sign_in(user)
      end

      it 'updates the pen' do
        expect do
          put :update, params: { id: collected_pen.id, collected_pen: { brand: 'Not Wing Sung' } }
          expect(response).to redirect_to(collected_pens_path(anchor: collected_pen.id))
        end.to change { collected_pen.reload.brand }.from('Wing Sung').to('Not Wing Sung')
      end

      it 'strips out whitespace' do
        expect do
          put :update, params: { id: collected_pen.id, collected_pen: { brand: ' Not Wing Sung ' } }
          expect(response).to redirect_to(collected_pens_path(anchor: collected_pen.id))
        end.to change { collected_pen.reload.brand }.from('Wing Sung').to('Not Wing Sung')
      end
    end
  end

  describe '#destroy' do

    let(:collected_pen) { collected_pens(:monis_wing_sung) }

    it 'requires authentication' do
      expect do
        delete :destroy, params: { id: collected_pen.id }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { CollectedPen.count }
    end

    describe 'signed in' do
      before(:each) do
        sign_in(user)
      end

      it 'deletes the collected pen' do
        expect do
          delete :destroy, params: { id: collected_pen.id }
          expect(response).to redirect_to(collected_pens_path)
        end.to change { CollectedPen.count }.by(-1)
      end

      it 'does not delete other users pens' do
        collected_pen = collected_pens(:toms_platinum)
        expect do
          delete :destroy, params: { id: collected_pen.id }
          expect(response).to redirect_to(collected_pens_path)
        end.to_not change { CollectedPen.count }
      end
    end
  end
end
