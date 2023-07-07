require "rails_helper"

describe Admins::Reviews::MissingController do
  let(:admin) { create(:user, :admin) }

  describe "#index" do
    it "requires authentication" do
      get "/admins/reviews/missing"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders successfully" do
        get "/admins/reviews/missing"
        expect(response).to be_successful
      end
    end
  end
end
