require "rails_helper"

describe Admins::Agents::InkClusterersController do
  let(:admin) { create(:user, :admin) }

  describe "#show" do
    it "requires authentication" do
      get "/admins/agents/ink_clusterer"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders successfully" do
        get "/admins/agents/ink_clusterer"
        expect(response).to be_successful
      end
    end
  end
end
