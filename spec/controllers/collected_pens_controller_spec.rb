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
end
