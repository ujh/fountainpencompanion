require 'rails_helper'
require 'csv'

describe Admins::UsersController do
  let(:admin) { create(:admin) }

  describe '#index' do
    it 'requires authentication' do
      get :index
      expect(response).to redirect_to(new_admin_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      pending 'renders' do
        get :index
        expect(response).to be_successful
      end
    end
  end

  describe '#ink_import' do
    let(:csv) do
      name = Rails.root.join('tmp', 'import.csv')
      CSV.open(name, 'w') do |csv|
        csv << %w(brand_name line_name ink_name kind private)
        csv << ['Diamine', 'Shimmertastic', 'Purple Pazzazz', 'bottle', 'x']
        csv << ['J. Herbin', '', 'Vert Olive', 'sample']
        csv << ['Pelikan', ' Edelstein ', 'Aventurine', 'sample']
      end
      name
    end
    let(:file_upload) { fixture_file_upload(csv) }
    let(:user) { create(:user) }

    it 'requires authentication' do
      post :ink_import, params: { id: user.id, file: file_upload }
      expect(response).to redirect_to(new_admin_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'processes the CSV file' do
        expect do
          post :ink_import, params: { id: user.id, file: file_upload }
          expect(ImportCollectedInk.jobs.size).to eq(3)
          ImportCollectedInk.drain
        end.to change { user.collected_inks.count }.by(3)
        expect(user.collected_inks.find_by(ink_name: 'Purple Pazzazz')).to be_private
        expect(user.collected_inks.find_by(ink_name: 'Vert Olive')).to_not be_private
        # Removes whitespace
        expect(user.collected_inks.find_by(ink_name: 'Aventurine').line_name).to eq('Edelstein')
      end
    end
  end
end
