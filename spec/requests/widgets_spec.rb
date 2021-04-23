require 'rails_helper'

describe WidgetsController do
  describe '#show' do
    context "inks_summary" do
      it "requires authentication" do
        get "/dashboard/widgets/inks_summary.json"
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns the required data when logged in" do
        user = create(:user)
        sign_in(user)
        get "/dashboard/widgets/inks_summary.json"
        expect(response).to be_successful
        p JSON.parse(response.body)
      end
    end
  end
end
