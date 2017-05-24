require 'rails_helper'

describe PrivaciesController do

  fixtures :collected_inks, :users

  let(:collected_ink) { collected_inks(:monis_marine) }
  let(:user) { users(:moni) }

  describe '#create' do

    it 'requires authentication' do
      post :create, params: { collected_ink_id: collected_ink.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      it 'sets private to true' do
        collected_ink.update_attributes(private: false)
        expect do
          post :create, params: { collected_ink_id: collected_ink.id }
        end.to change { collected_ink.reload.private }.from(false).to(true)
      end

      it 'fails if the collected ink belongs to another user' do
        expect do
          post :create, params: { collected_ink_id: collected_inks(:toms_marine).id }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

  end

  describe '#destroy' do

    it 'requires authentication' do
      delete :destroy, params: { collected_ink_id: collected_ink.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do

      before(:each) do
        sign_in(user)
      end

      it 'sets private to false' do
        collected_ink.update_attributes(private: true)
        expect do
          delete :destroy, params: { collected_ink_id: collected_ink.id }
        end.to change { collected_ink.reload.private }.from(true).to(false)
      end

      it 'fails if the collected ink belongs to another user' do
        expect do
          delete :destroy, params: { collected_ink_id: collected_inks(:toms_marine).id }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

    end

  end

end
