require "rails_helper"

describe "Admins::Reviews" do
  let(:admin) { create(:user, :admin) }

  describe "GET /admins/reviews" do
    it "requires authentication" do
      get "/admins/reviews"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders successfully" do
        get "/admins/reviews"
        expect(response).to be_successful
      end
    end
  end

  describe "PUT /admins/reviews/:id" do
    let(:ink_review) { create(:ink_review) }

    it "requires authentication" do
      put "/admins/reviews/#{ink_review.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "approves the review" do
        expect do put "/admins/reviews/#{ink_review.id}" end.to change {
          ink_review.reload.approved?
        }.from(false).to(true)
      end

      it "keeps redirects to the reviews index page with the page param if another review exists" do
        create(:ink_review, approved_at: Time.current, agent_approved: true)
        put "/admins/reviews/#{ink_review.id}?page=2"
        expect(response).to redirect_to("/admins/reviews?page=2")
      end
    end
  end

  describe "DELETE /admins/reviews/:id" do
    let(:ink_review) { create(:ink_review) }

    it "requires authentication" do
      delete "/admins/reviews/#{ink_review.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "rejects the review" do
        expect do delete "/admins/reviews/#{ink_review.id}" end.to change {
          ink_review.reload.rejected?
        }.from(false).to(true)
      end

      it "ignores the YouTube channel when rejecting a review with ignore_youtube_channel param" do
        youtube_channel = create(:you_tube_channel, ignored: false)
        ink_review_with_channel = create(:ink_review, you_tube_channel: youtube_channel)

        expect do
          delete "/admins/reviews/#{ink_review_with_channel.id}?ignore_youtube_channel=true"
        end.to change { youtube_channel.reload.ignored? }.from(false).to(true)

        expect(ink_review_with_channel.reload.rejected?).to be true
      end
    end
  end
end
