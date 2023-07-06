require "rails_helper"

describe Pens::NibsController do
  let(:user) { create(:user) }

  before do
    create(:collected_pen, user: user, nib: "fine")
    create(:collected_pen, user: user, nib: "broad")

    sign_in(user)
  end

  describe "#index" do
    it "returns all nibs with an empty search term" do
      get :index, params: { term: "" }, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(%w[broad fine])
    end

    it "returns nibs by substring search" do
      get :index, params: { term: "b" }, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(%w[broad])
    end

    it "does not return data from other users" do
      create(:collected_pen, nib: "other")

      get :index, params: { term: "" }, format: :json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(%w[broad fine])
    end
  end
end
