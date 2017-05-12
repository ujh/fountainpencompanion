require 'rails_helper'

describe InksController do

  fixtures :manufacturers, :inks, :users
  render_views

  let(:user) { users(:moni) }

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      let(:manufacturer) { manufacturers(:diamine) }
      let(:ink) { inks(:marine) }
      let!(:collected_ink) { CollectedInk.create!(user: user, ink: ink) }

      before(:each) do
        sign_in(user)
      end

      it 'renders the ink index page' do
        get :index
        expect(response).to be_successful
        expect(response.body).to include(manufacturer.name)
        expect(response.body).to include(ink.name)
      end
    end
  end

  describe '#create' do
    it 'requires authentication' do
      expect do
        expect do
          post :create, params: { collected_ink: { ink_name: 'Ink', manufacturer_name: 'Manufacturer'}}
          expect(response).to redirect_to(new_user_session_path)
        end.to_not change { Manufacturer.count }
      end.to_not change { Ink.count }
    end

    context 'signed in' do
      before(:each) do
        sign_in(user)
      end

      it 'creates the data' do
        expect do
          expect do
            expect do
              post :create, params: { collected_ink: {
                ink_name: 'Ink',
                manufacturer_name: 'Manufacturer',
                kind: 'bottle'
              }}
              expect(response).to redirect_to(inks_path)
            end.to change { Manufacturer.count }.by(1)
          end.to change { Ink.count }.by(1)
        end.to change { user.collected_inks.count }.by(1)
        collected_ink = user.collected_inks.last
        expect(collected_ink.manufacturer_name).to eq('Manufacturer')
        expect(collected_ink.ink_name).to eq('Ink')
        expect(collected_ink.kind).to eq('bottle')
      end
    end
  end

  describe '#update' do
    fixtures :collected_inks

    let(:collected_ink) { collected_inks(:monis_marine) }

    it 'requires authentication' do
      expect do
        put :update, params: { id: collected_ink.id, collected_ink: { ink_name: 'Not Marine' } }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { Ink.count }
    end

    context 'signed in' do
      let(:user) { users(:moni) }

      before(:each) do
        sign_in(user)
      end

      it 'updates the ink' do
        expect do
          expect do
            put :update, params: { id: collected_ink.id, collected_ink: { ink_name: 'Not Marine' } }
            expect(response).to redirect_to(inks_path)
            collected_ink.reload
            expect(collected_ink.manufacturer_name).to eq('Diamine')
            expect(collected_ink.ink_name).to eq('Not Marine')
            expect(collected_ink.kind).to eq('bottle')
          end.to change { Ink.count }.by(1)
        end.to_not change { Manufacturer.count }
      end

      it 'updates the manufacturer' do
        expect do
          expect do
            put :update, params: { id: collected_ink.id, collected_ink: { manufacturer_name: 'Not Diamine' } }
            expect(response).to redirect_to(inks_path)
            collected_ink.reload
            expect(collected_ink.manufacturer_name).to eq('Not Diamine')
            expect(collected_ink.ink_name).to eq('Marine')
            expect(collected_ink.kind).to eq('bottle')
          end.to change { Ink.count }.by(1)
        end.to change { Manufacturer.count }.by(1)
      end

      it 'updates the kind' do
        expect do
          expect do
            put :update, params: { id: collected_ink.id, collected_ink: { kind: 'sample' } }
            expect(response).to redirect_to(inks_path)
            collected_ink.reload
            expect(collected_ink.manufacturer_name).to eq('Diamine')
            expect(collected_ink.ink_name).to eq('Marine')
            expect(collected_ink.kind).to eq('sample')
          end.to_not change { Ink.count }
        end.to_not change { Manufacturer.count }
      end
    end
  end

  describe '#destroy' do
    fixtures :collected_inks

    let(:collected_ink) { collected_inks(:monis_marine) }
    it 'requires authentication' do
      expect do
        delete :destroy, params: { id: collected_ink.id }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { CollectedInk.count }
    end

    describe 'signed in' do
      let(:user) { users(:moni) }

      before(:each) do
        sign_in(user)
      end

      it 'deletes the collected ink' do
        expect do
          delete :destroy, params: { id: collected_ink.id }
          expect(response).to redirect_to(inks_path)
        end.to change { user.collected_inks.count }.by(-1)
      end

      it 'does not delete other users inks' do
        expect do
          delete :destroy, params: { id: collected_inks(:toms_marine) }
          expect(response).to redirect_to(inks_path)
        end.to_not change { CollectedInk.count }
      end
    end
  end
end
