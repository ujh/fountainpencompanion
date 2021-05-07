require 'rails_helper'

describe Admins::MacroClustersController do
  let(:admin) { create(:admin) }

  describe '#index' do
    it 'requires authentication' do
      get '/admins/macro_clusters'
      expect(response).to redirect_to(new_admin_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'renders the clusters' do
        macro_cluster = create(:macro_cluster)
        micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
        collected_ink = create(:collected_ink, micro_cluster: micro_cluster)
        get '/admins/macro_clusters.json'
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq(
          'data' => [{
            'id' => macro_cluster.id,
            'brand_name' => macro_cluster.brand_name,
            'line_name' => macro_cluster.line_name,
            'ink_name' => macro_cluster.ink_name,
            'color' => macro_cluster.color,
            'collected_inks' => [{
              'id' => collected_ink.id,
              'brand_name' => collected_ink.brand_name,
              'line_name' => collected_ink.line_name,
              'ink_name' => collected_ink.ink_name,
              'maker' => collected_ink.maker,
              'color' => collected_ink.color,
            }]
          }],
          'meta' => {
            'pagination' => {
              'total_pages' => 1,
              'current_page' => 1,
              'next_page' => nil,
              'prev_page' => nil,
            }
          }
        )
      end

      pending 'does not include duplicate collected inks' do
        macro_cluster = create(:macro_cluster)
        micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
        collected_ink = create(:collected_ink, micro_cluster: micro_cluster)
        collected_ink2 = create(
          :collected_ink,
          micro_cluster: micro_cluster,
          brand_name: collected_ink.brand_name,
          line_name: collected_ink.line_name,
          ink_name: collected_ink.ink_name
        )
        get '/admins/macro_clusters.json'
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq(
          'data' => [{
            'id' => macro_cluster.id,
            'brand_name' => macro_cluster.brand_name,
            'line_name' => macro_cluster.line_name,
            'ink_name' => macro_cluster.ink_name,
            'color' => macro_cluster.color,
            'collected_inks' => [{
              'id' => collected_ink.id,
              'brand_name' => collected_ink.brand_name,
              'line_name' => collected_ink.line_name,
              'ink_name' => collected_ink.ink_name,
              'maker' => collected_ink.maker,
              'color' => collected_ink.color,
            }]
          }],
          'meta' => {
            'pagination' => {
              'total_pages' => 1,
              'current_page' => 1,
              'next_page' => nil,
              'prev_page' => nil,
            }
          }
        )
      end

      it 'includes collected inks that differ partially' do
        macro_cluster = create(:macro_cluster)
        micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
        collected_ink = create(:collected_ink, micro_cluster: micro_cluster)
        collected_ink2 = create(
          :collected_ink,
          micro_cluster: micro_cluster,
          brand_name: collected_ink.brand_name,
          line_name: collected_ink.line_name,
          ink_name: collected_ink.ink_name + "123"
        )
        get '/admins/macro_clusters.json'
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to match(
          'data' => [{
            'id' => macro_cluster.id,
            'brand_name' => macro_cluster.brand_name,
            'line_name' => macro_cluster.line_name,
            'ink_name' => macro_cluster.ink_name,
            'color' => macro_cluster.color,
            'collected_inks' => match_array([{
              'id' => collected_ink.id,
              'brand_name' => collected_ink.brand_name,
              'line_name' => collected_ink.line_name,
              'ink_name' => collected_ink.ink_name,
              'maker' => collected_ink.maker,
              'color' => collected_ink.color,
            }, {
              'id' => collected_ink2.id,
              'brand_name' => collected_ink2.brand_name,
              'line_name' => collected_ink2.line_name,
              'ink_name' => collected_ink2.ink_name,
              'maker' => collected_ink2.maker,
              'color' => collected_ink2.color,
            }])
          }],
          'meta' => {
            'pagination' => {
              'total_pages' => 1,
              'current_page' => 1,
              'next_page' => nil,
              'prev_page' => nil,
            }
          }
        )
      end

      it 'includes micro clusters without collected inks' do
        macro_cluster = create(:macro_cluster)
        micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
        get '/admins/macro_clusters.json'
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq(
          'data' => [{
            'id' => macro_cluster.id,
            'brand_name' => macro_cluster.brand_name,
            'line_name' => macro_cluster.line_name,
            'ink_name' => macro_cluster.ink_name,
            'color' => macro_cluster.color,
            'collected_inks' => []
          }],
          'meta' => {
            'pagination' => {
              'total_pages' => 1,
              'current_page' => 1,
              'next_page' => nil,
              'prev_page' => nil,
            }
          }
        )
      end

      it 'includes macro clusters without micro clusters' do
        macro_cluster = create(:macro_cluster)
        get '/admins/macro_clusters.json'
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq({
          'data' => [{
            'id' => macro_cluster.id,
            'brand_name' => macro_cluster.brand_name,
            'line_name' => macro_cluster.line_name,
            'ink_name' => macro_cluster.ink_name,
            'color' => macro_cluster.color,
            'collected_inks' => []
          }],
          'meta' => {
            'pagination' => {
              'total_pages' => 1,
              'current_page' => 1,
              'next_page' => nil,
              'prev_page' => nil,
            }
          }
        })
      end
    end
  end

  describe '#create' do
    let(:params) do
      {
        data: {
          type: 'macro_cluster',
          attributes: {
            brand_name: 'brand_name',
            line_name: 'line_name',
            ink_name: 'ink_name',
            color: '#FFFFFF'
          }
        }
      }
    end

    it 'requires authentication' do
      expect do
        post '/admins/macro_clusters', params: params
        expect(response).to redirect_to(new_admin_session_path)
      end.to_not change { MacroCluster.count }
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'creates the cluster' do
        expect do
          post '/admins/macro_clusters', params: params
          expect(response).to be_successful
        end.to change { MacroCluster.count }.by(1)
        cluster = MacroCluster.last
        expect(cluster.brand_name).to eq('brand_name')
        expect(cluster.line_name).to eq('line_name')
        expect(cluster.ink_name).to eq('ink_name')
        expect(cluster.color).to eq('#FFFFFF')
        expect(JSON.parse(response.body)).to match({
          'data' => {
            'id' => cluster.id.to_s,
            'type' => 'macro_cluster',
            'attributes' => {
              'brand_name' => 'brand_name',
              'line_name' => 'line_name',
              'ink_name' => 'ink_name',
              'color' => '#FFFFFF'
            },
            'relationships' => {
              'micro_clusters' => { 'data' => [] }
            }
          }
        })
      end
    end
  end

  describe '#update' do
    let!(:macro_cluster) { create(:macro_cluster) }
    let(:params) do
      {
        data: {
          id: macro_cluster.id.to_s,
          type: 'macro_cluster',
          attributes: {
            brand_name: 'new brand_name',
            line_name: 'new line_name',
            ink_name: 'new ink_name',
            color: '#000000'
          }
        }
      }
    end

    it 'requires authentication' do
      put "/admins/macro_clusters/#{macro_cluster.id}", params: params
      expect(response).to redirect_to(new_admin_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'updates the cluster' do
        put "/admins/macro_clusters/#{macro_cluster.id}", params: params
        expect(response).to be_successful
        macro_cluster.reload
        expect(macro_cluster.brand_name).to eq('new brand_name')
        expect(macro_cluster.line_name).to eq('new line_name')
        expect(macro_cluster.ink_name).to eq('new ink_name')
        expect(macro_cluster.color).to eq('#000000')
        expect(JSON.parse(response.body)).to match({
          'data' => {
            'id' => macro_cluster.id.to_s,
            'type' => 'macro_cluster',
            'attributes' => {
              'brand_name' => 'new brand_name',
              'line_name' => 'new line_name',
              'ink_name' => 'new ink_name',
              'color' => '#000000'
            },
            'relationships' => {
              'micro_clusters' => { 'data' => [] }
            }
          }
        })
      end
    end
  end

  describe '#destroy' do
    let!(:macro_cluster) { create(:macro_cluster) }

    it 'requires authentication' do
      expect do
        delete "/admins/macro_clusters/#{macro_cluster.id}"
        expect(response).to redirect_to(new_admin_session_path)
      end.to_not change { MacroCluster.count }
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'deletes the cluster' do
        expect do
          delete "/admins/macro_clusters/#{macro_cluster.id}"
          expect(response).to be_successful
        end.to change { MacroCluster.count }.by(-1)
      end
    end
  end
end
