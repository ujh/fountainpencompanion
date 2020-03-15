require 'rails_helper'

describe Admins::MacroClustersController do
  let(:admin) { create(:admin) }

  describe '#index' do

  end

  describe '#create' do

  end

  describe '#update' do

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
