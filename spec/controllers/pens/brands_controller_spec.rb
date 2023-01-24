require "rails_helper"

describe Pens::BrandsController do
  let(:user) { create(:user) }
  let(:wing_sung) { create(:collected_pen, user: user, brand: "Wing Sung") }
  let(:custom74) do
    create(
      :collected_pen,
      user: user,
      brand: "Pilot",
      model: "Custom 74",
      nib: "M",
      color: "Orange"
    )
  end
  let(:platinum) do
    create(:collected_pen, brand: "Platinum", model: "3776 Chartres")
  end
  let(:pens) { [wing_sung, custom74, platinum] }

  before { pens }

  describe "#index" do
    it "returns all brands with an empty search term" do
      get :index, params: { term: "" }, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(
        ["Pilot", "Platinum", "Wing Sung"]
      )
    end

    it "returns brands by substring search" do
      get :index, params: { term: "P" }, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(%w[Pilot Platinum])
    end
  end
end
