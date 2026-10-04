require "rails_helper"

describe Admins::StatsController, type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe "GET /admins/stats/:id" do
    context "when not authenticated" do
      it "redirects to login" do
        get "/admins/stats/user_count"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in(regular_user) }

      it "is not allowed" do
        get "/admins/stats/user_count"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as admin" do
      before { sign_in(admin) }

      it "returns the value for a known no-arg stat" do
        create(:user)
        get "/admins/stats/user_count"
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq(User.active.count)
      end

      it "returns the value for a known arg-taking stat" do
        get "/admins/stats/pens_micro_clusters_prio_to_assign_count?arg=2"
        expect(response).to be_successful
        expect(response.body).to match(/\A\d+\z/)
      end

      it "uses the method default when an arg-taking stat is called with no arg" do
        # The dashboard view calls these stats both with and without arg —
        # without arg the AdminStats method's default value must apply.
        get "/admins/stats/pens_micro_clusters_prio_to_assign_count"
        expect(response).to be_successful
        expect(response.body).to match(/\A\d+\z/)
      end

      it "returns 404 for an unknown stat name" do
        get "/admins/stats/nope_not_a_real_stat"
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for a private/Kernel method (security regression)" do
        get "/admins/stats/eval", params: { arg: "`whoami`" }
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for a private/Kernel method without arg" do
        get "/admins/stats/instance_eval"
        expect(response).to have_http_status(:not_found)
      end

      it "returns 400 when arg is not coercible to Integer" do
        get "/admins/stats/pens_micro_clusters_prio_to_assign_count?arg=notanint"
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
