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

      it "returns the required data when logged in" do
        user = create(:user)
        sign_in(user)
        2.times { create(:collected_ink, brand_name: 'Herbin', user: user) }
        3.times { create(:collected_ink, brand_name: 'Diamine', user: user) }
        create(:collected_ink, brand_name: 'Sailor', user: user)
        get url
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq({
          'data' => {
            'type' => 'widget',
            'id' => 'inks_grouped_by_brand',
            'attributes' => {
              'brands' => [
                {'brand_name' => 'Diamine', 'count' => 3},
                {'brand_name' => 'Herbin', 'count' => 2},
                {'brand_name' => 'Sailor', 'count' => 1},
              ]
            }
          }
        })
      end
    end

    context 'pens_grouped_by_brand' do
      let(:url) { "/dashboard/widgets/pens_grouped_by_brand.json" }

      include_examples "authentication"

      it "returns the required data when logged in" do
        user = create(:user)
        sign_in(user)
        2.times { create(:collected_pen, brand: 'Sailor', user: user) }
        create(:collected_pen, brand: 'Pelikan', user: user)
        3.times { create(:collected_pen, brand: 'Platinum', user: user) }
        get url
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq({
          'data' => {
            'type' => 'widget',
            'id' => 'pens_grouped_by_brand',
            'attributes' => {
              'brands' => [
                {'brand_name' => 'Platinum', 'count' => 3},
                {'brand_name' => 'Sailor', 'count' => 2},
                {'brand_name' => 'Pelikan', 'count' => 1}
              ]
            }
          }
        })
      end
    end
  end
end
