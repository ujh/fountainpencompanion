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

  describe '#pen_import' do
    let(:csv) do
      name = Rails.root.join('tmp', 'import.csv')
      CSV.open(name, 'w') do |csv|
        csv << %w(brand model comment nib color)
        csv << ['PenBBS', '456', 'comment', 'F', '  blue  ']
      end
      name
    end
    let(:file_upload) { fixture_file_upload(csv) }
    let(:user) { create(:user) }

    it 'requires authentication' do
      post :pen_import, params: { id: user.id, file: file_upload }
      expect(response).to redirect_to(new_admin_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'processes the CSV file' do
        expect do
          post :pen_import, params: { id: user.id, file: file_upload }
          expect(ImportCollectedPen.jobs.size).to eq(1)
          ImportCollectedPen.drain
        end.to change { user.collected_pens.count }.by(1)
        pen = user.collected_pens.last
        expect(pen.brand).to eq('PenBBS')
        expect(pen.model).to eq('456')
        expect(pen.nib).to eq('F')
        expect(pen.color).to eq('blue') # strips whitespace
        expect(pen.comment).to eq('comment')
      end
    end
  end

end
