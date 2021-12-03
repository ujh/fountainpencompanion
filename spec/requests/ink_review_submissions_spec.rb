require 'rails_helper'

describe "InkReviewSubmissions" do
  describe 'POST' do
    let(:brand_cluster) { create(:brand_cluster) }
    let(:macro_cluster) { create(:macro_cluster, brand_cluster: brand_cluster) }
    let(:path) { "/brands/#{brand_cluster.id}/inks/#{macro_cluster.id}/ink_review_submissions" }

    it 'requires authentication' do
      post path
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'signed in' do
      let(:user) { create(:user, name: 'the name') }

      before(:each) do
        sign_in(user)
      end

      it 'creates a new submission' do
        expect do
          post path, params: { ink_review_submission: { url: 'http://example.com' } }
        end.to change(InkReviewSubmission, :count).by(1)
      end

      it 'assigns the submission to the user' do
        post path, params: { ink_review_submission: { url: 'http://example.com' } }
        submission = InkReviewSubmission.first
        expect(submission.user).to eq(user)
      end

      it 'assigns the submission to the macro cluster' do
        post path, params: { ink_review_submission: { url: 'http://example.com' } }
        submission = InkReviewSubmission.first
        expect(submission.macro_cluster).to eq(macro_cluster)
      end

      it 'sets the correct url' do
        post path, params: { ink_review_submission: { url: 'http://example.com' } }
        submission = InkReviewSubmission.first
        expect(submission.url).to eq('http://example.com')
      end
    end
  end
end
