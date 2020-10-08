require 'rails_helper'

describe AccountsController do
  describe '#show' do
    it 'requires authentication' do
      get '/account'
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      let(:user) { create(:user, name: 'the name') }

      before(:each) do
        sign_in(user)
      end

      it 'renders a page' do
        get '/account'
        expect(response).to be_successful
      end

      it 'renders json if requested' do
        get '/account.jsonapi'
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to eq(
          "data" => {
            "id" => user.id.to_s,
            "type" => "user",
            "attributes" => {"name" => "the name"},
            "relationships" => {"collected_inks" => {"data" => []}}
          },
          "jsonapi" => {"version" => "1.0"}
        )
      end

      it 'includes public inks' do
        ink = create(:collected_ink, user: user)
        get '/account.jsonapi'
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json['data']['relationships']['collected_inks']['data']).to eq([{
          'type' => 'collected_inks', 'id' => ink.id.to_s
        }])
        expect(json['included']).to eq([{
          'id' => ink.id.to_s,
          'type' => 'collected_inks',
          'attributes' => {
            'archived' => false,
            'archived_on' => nil,
            'brand_name' => ink.brand_name,
            'color' => ink.color,
            'comment' => ink.comment,
            'daily_usage' => 0,
            'deletable' => true,
            'ink_id' => nil,
            'ink_name' => ink.ink_name,
            'kind' => ink.kind,
            'line_name' => ink.line_name,
            'maker' => ink.maker,
            'private' => ink.private,
            'private_comment' => ink.private_comment,
            'simplified_brand_name' => ink.simplified_brand_name,
            'simplified_ink_name' => ink.simplified_ink_name,
            'simplified_line_name' => ink.simplified_line_name,
            'swabbed' => ink.swabbed,
            'usage' => 0,
            'used' => false
          }
        }])
      end

      it 'does not include private inks' do
        ink = create(:collected_ink, user: user, private: true)
        get '/account.jsonapi'
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json['data']['relationships']['collected_inks']['data']).to eq([])
      end
    end
  end

  describe '#update' do
    it 'requires authentication' do
      put '/account'
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      let(:user) { create(:user, name: 'the name') }

      before(:each) do
        sign_in(user)
      end

      it 'updates the user data' do
        put '/account', params: { user: { name: 'new name' } }
        expect(response).to redirect_to(account_path)
        expect(user.reload.name).to eq('new name')
      end

      it 'also supports json requests' do
        put '/account', params: { user: { name: 'new name' } }, as: :json
        expect(response).to be_successful
        expect(user.reload.name).to eq('new name')
      end
    end
  end
end
