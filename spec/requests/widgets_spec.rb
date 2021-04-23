require 'rails_helper'

describe WidgetsController do
  describe '#show' do
    shared_examples "authentication" do
      it "requires authentication" do
        get url
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "inks_summary" do
      let(:url) { "/dashboard/widgets/inks_summary.json" }

      include_examples "authentication"

      it "returns the required data when logged in" do
        user = create(:user)
        sign_in(user)
        get url
        expect(response).to be_successful
      end
    end

    context 'inks_grouped_by_brand' do
      let(:url) { "/dashboard/widgets/inks_grouped_by_brand.json" }

      include_examples "authentication"
    end
  end
end
