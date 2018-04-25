require 'rails_helper'

describe CollectedInksController do

  fixtures :collected_inks, :users
  render_views

  let(:user) { users(:moni) }

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      let(:ink) { collected_inks(:monis_marine) }

      before(:each) do
        sign_in(user)
      end

      it 'renders the ink index page' do
        get :index
        expect(response).to be_successful
      end

      it 'renders the CSV' do
        get :index, format: "csv"
        expect(response).to be_successful
        csv = CSV.generate(col_sep: ";") do |csv|
          csv << [
            "Brand",
            "Line",
            "Name",
            "Type",
            "Color",
            "Swabbed",
            "Used",
            "Comment",
            "Archived",
            "Usage"
          ]
          [:monis_marine, :monis_syrah, :monis_fire_and_ice].each do |k|
            ci = collected_inks(k)
            csv << [
              ci.brand_name,
              ci.line_name,
              ci.ink_name,
              ci.kind,
              ci.color,
              ci.swabbed,
              ci.used,
              ci.comment,
              ci.archived?,
              ci.currently_inkeds.count
            ]
          end
        end
        expect(response.body).to eq(csv)
      end

      it 'renders the JSON' do
        get :index, format: :jsonapi
        expect(response).to be_successful
        expect(response.body).to include(ink.ink_name)
        expect(response.body).to include(ink.brand_name)
      end
    end
  end

  describe '#create' do
    it 'requires authentication' do
      expect do
        payload = { data: {
          type: 'collected_ink',
          attributes: {
            ink_name: 'Ink',
            line_name: 'Line',
            brand_name: 'Brand',
            kind: 'bottle'
          }
        }}
        post :create, params: { _jsonapi: payload }
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { CollectedInk.count }
    end

    context 'signed in' do
      before(:each) do
        sign_in(user)
      end

      it 'creates the data' do
        payload = { data: {
          type: 'collected_ink',
          attributes: {
            ink_name: 'Ink',
            line_name: 'Line',
            brand_name: 'Brand',
            kind: 'bottle'
          }
        }}
        expect do
          post :create, params: { _jsonapi: payload }
          collected_ink = CollectedInk.order(:id).last
          expect(response).to be_successful
        end.to change { user.collected_inks.count }.by(1)
        json = JSON.parse(response.body)
        collected_ink = user.collected_inks.last
        expect(json["data"]).to include("id" => collected_ink.id.to_s)
        expect(json["data"]["attributes"]).to include(
          "brand_name" => "Brand",
          "line_name" => "Line",
          "ink_name" => "Ink",
          "kind" => "bottle"
        )
        expect(collected_ink.brand_name).to eq('Brand')
        expect(collected_ink.line_name).to eq('Line')
        expect(collected_ink.ink_name).to eq('Ink')
        expect(collected_ink.kind).to eq('bottle')
      end

      it 'strips out extraneous whitespace' do
        payload = { data: {
          type: 'collected_ink',
          attributes: {
            ink_name: ' Ink ',
            line_name: ' Line ',
            brand_name: ' Brand ',
            kind: 'bottle'
          }
        }}
        expect do
          post :create, params: { _jsonapi: payload }
          collected_ink = CollectedInk.order(:id).last
          expect(response).to be_successful
        end.to change { user.collected_inks.count }.by(1)
        json = JSON.parse(response.body)
        collected_ink = user.collected_inks.last
        expect(json["data"]).to include("id" => collected_ink.id.to_s)
        expect(json["data"]["attributes"]).to include(
          "brand_name" => "Brand",
          "line_name" => "Line",
          "ink_name" => "Ink",
          "kind" => "bottle"
        )
        expect(collected_ink.brand_name).to eq('Brand')
        expect(collected_ink.line_name).to eq('Line')
        expect(collected_ink.ink_name).to eq('Ink')
        expect(collected_ink.kind).to eq('bottle')
      end
    end
  end

  describe '#update' do

    let(:collected_ink) { collected_inks(:monis_marine) }

    it 'requires authentication' do
      expect do
        payload = { data: { type: 'collected_ink', attributes: { ink_name: 'Not Marine' } } }
        put :update, params: { id: collected_ink.id, _jsonapi: payload}
        expect(response).to redirect_to(new_user_session_path)
      end.to_not change { collected_ink.reload }
    end

    context 'signed in' do
      let(:user) { users(:moni) }

      before(:each) do
        sign_in(user)
      end

      it 'updates the ink' do
        payload = { data: { type: 'collected_ink', attributes: { ink_name: 'Not Marine' } } }
        put :update, params: { id: collected_ink.id, _jsonapi: payload}
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json["data"]).to include("id" => collected_ink.id.to_s)
        expect(json["data"]["attributes"]).to include("ink_name" => "Not Marine")
        collected_ink.reload
        expect(collected_ink.ink_name).to eq('Not Marine')
      end

      it 'strips out whitespace' do
        payload = { data: {
          type: 'collected_ink',
          attributes: {
            ink_name: ' Not Marine ',
            line_name: ' Not 1670 ',
            brand_name: ' Not Diamine ',
          }
        }}
        put :update, params: { id: collected_ink.id, _jsonapi: payload}
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json["data"]).to include("id" => collected_ink.id.to_s)
        expect(json["data"]["attributes"]).to include(
          "ink_name" => "Not Marine",
          "line_name" => "Not 1670",
          "brand_name" => "Not Diamine"
        )
        collected_ink.reload
        expect(collected_ink.ink_name).to eq('Not Marine')
        expect(collected_ink.line_name).to eq('Not 1670')
        expect(collected_ink.brand_name).to eq('Not Diamine')
      end
    end
  end

  describe '#destroy' do

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
          expect(response).to be_successful
        end.to change { user.collected_inks.count }.by(-1)
      end

      it 'does not delete other users inks' do
        expect do
          expect do
            delete :destroy, params: { id: collected_inks(:toms_marine) }
          end.to raise_error(ActiveRecord::RecordNotFound)
        end.to_not change { CollectedInk.count }
      end
    end
  end
end
