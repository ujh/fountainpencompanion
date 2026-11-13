require "rails_helper"

describe "InkReviewLoves" do
  let(:ink_review) { create(:ink_review, approved_at: Time.current) }
  let(:path) { "/ink_reviews/#{ink_review.id}/love" }
  let(:user) { create(:user) }

  describe "POST" do
    it "requires authentication" do
      post path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before { sign_in(user) }

      it "loves the review" do
        expect { post path, as: :json }.to change { ink_review.loves.where(user: user).count }.by(1)
      end

      it "returns the love state and count" do
        create(:ink_review_love, ink_review: ink_review)

        post path, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("loved" => true, "loves_count" => 2)
      end

      it "does not love the review twice" do
        create(:ink_review_love, ink_review: ink_review, user: user)

        expect { post path, as: :json }.not_to change(InkReviewLove, :count)
        expect(response.parsed_body).to eq("loved" => true, "loves_count" => 1)
      end

      it "returns not found for a review that is not live" do
        queued_review = create(:ink_review)

        post "/ink_reviews/#{queued_review.id}/love", as: :json

        expect(response).to have_http_status(:not_found)
        expect(InkReviewLove.count).to eq(0)
      end

      it "returns not found for a review with a broken link" do
        broken_review = create(:ink_review, approved_at: Time.current, check_count: 1)

        post "/ink_reviews/#{broken_review.id}/love", as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE" do
    it "requires authentication" do
      delete path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before { sign_in(user) }

      it "removes the user's love" do
        create(:ink_review_love, ink_review: ink_review, user: user)

        expect { delete path, as: :json }.to change(InkReviewLove, :count).by(-1)
      end

      it "keeps the loves of other users" do
        create(:ink_review_love, ink_review: ink_review)
        create(:ink_review_love, ink_review: ink_review, user: user)

        delete path, as: :json

        expect(response.parsed_body).to eq("loved" => false, "loves_count" => 1)
      end

      it "succeeds when the review was not loved" do
        delete path, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("loved" => false, "loves_count" => 0)
      end

      it "returns not found for a review that is not live" do
        rejected_review = create(:ink_review, rejected_at: Time.current)

        delete "/ink_reviews/#{rejected_review.id}/love", as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
