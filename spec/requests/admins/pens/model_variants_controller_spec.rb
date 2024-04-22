require "rails_helper"

describe Admins::Pens::ModelVariantsController do
  let(:admin) { create(:user, :admin) }

  it "requires authentication" do
    get "/admins/pens/model_variants"
    expect(response).to redirect_to(new_user_session_path)
  end

  context "signed in" do
    before(:each) { sign_in(admin) }

    it "renders the json" do
      model_variant = create(:pens_model_variant)
      pens_micro_cluster = create(:pens_micro_cluster, model_variant:)
      collected_pen = create(:collected_pen, pens_micro_cluster:)
      get "/admins/pens/model_variants.json"
      expect(response).to be_successful
      json = JSON.parse(response.body)
      pp json
    end
  end
end
