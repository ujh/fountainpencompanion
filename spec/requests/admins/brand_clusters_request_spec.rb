require 'rails_helper'

describe Admins::BrandClustersController do
  let(:admin) { create(:admin) }

  describe '#new' do
    it 'requires authentication' do
      get '/admins/brand_clusters/new'
      expect(response).to redirect_to(new_admin_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'renders the page' do
        create(:macro_cluster)
        get '/admins/brand_clusters/new'
        expect(response).to be_successful
      end
    end
  end
end
