require 'rails_helper'

describe CollectedPensController do
  render_views

  let(:user) { create(:user) }
  let!(:wing_sung) { create(:collected_pen, user: user) }
  let!(:custom74) { create(:collected_pen, user: user, brand: 'Pilot', model: 'Custom 74', nib: 'M', color: 'Orange') }
  let!(:platinum) { create(:collected_pen, brand: 'Platinum', model: '3776 Chartres') }

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
        expect(response).to be_successful
        expect(response.body).to include(wing_sung.brand)
        expect(response.body).to include(wing_sung.model)
      end

      it 'renders the csv export' do
        get :index, format: "csv"
        expect(response).to be_successful
        expected_csv = CSV.generate(col_sep: ";") do |csv|
          csv << ["Brand", "Model", "Nib", "Color", "Comment", "Archived", "Archived On", "Usage"]
          [custom74, wing_sung].each do |cp|
            csv << [
              cp.brand,
              cp.model,
              cp.nib,
              cp.color,
              cp.comment,
              cp.archived?,
              cp.archived_on,
              cp.currently_inkeds.length
            ]
          end
        end
        expect(response.body).to eq(expected_csv)
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
          expect(response).to redirect_to(collected_pens_path(anchor: "add-form"))
        end.to change { user.collected_pens.count }.by(1)
        collected_pen = user.collected_pens.order(:id).last
        expect(collected_pen.brand).to eq('Pelikan')
        expect(collected_pen.model).to eq('M205')
      end
    end
  end

  describe '#update' do

    it 'requires authentication' do
      expect do
        put :update, params: { id: wing_sung.id, collected_pen: { brand: 'Not Wing Sung' } }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { wing_sung.reload }
    end

    context 'signed in' do
      before(:each) do
        sign_in(user)
      end

      it 'updates the pen' do
        expect do
          put :update, params: { id: wing_sung.id, collected_pen: { brand: 'Not Wing Sung' } }
          expect(response).to redirect_to(collected_pens_path(anchor: wing_sung.id))
        end.to change { wing_sung.reload.brand }.from('Wing Sung').to('Not Wing Sung')
      end

      it 'strips out whitespace' do
        expect do
          put :update, params: { id: wing_sung.id, collected_pen: { brand: ' Not Wing Sung ' } }
          expect(response).to redirect_to(collected_pens_path(anchor: wing_sung.id))
        end.to change { wing_sung.reload.brand }.from('Wing Sung').to('Not Wing Sung')
      end
    end
  end

  describe '#destroy' do

    it 'requires authentication' do
      expect do
        delete :destroy, params: { id: wing_sung.id }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { CollectedPen.count }
    end

    describe 'signed in' do
      before(:each) do
        sign_in(user)
      end

      it 'deletes the collected pen' do
        expect do
          delete :destroy, params: { id: wing_sung.id }
          expect(response).to redirect_to(collected_pens_path)
        end.to change { CollectedPen.count }.by(-1)
      end

      it 'does not delete other users pens' do
        expect do
          delete :destroy, params: { id: platinum.id }
          expect(response).to redirect_to(collected_pens_path)
        end.to_not change { CollectedPen.count }
      end
    end
  end
end
