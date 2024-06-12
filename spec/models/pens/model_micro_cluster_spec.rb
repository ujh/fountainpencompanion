require "rails_helper"

RSpec.describe Pens::ModelMicroCluster do
  describe "associations" do
    it "has a properly set up model variants association" do
      mmc = create(:pens_model_micro_cluster)
      mv1 = create(:pens_model_variant, model_micro_cluster: mmc)
      mv2 = create(:pens_model_variant, model_micro_cluster: mmc)

      expect(mmc.model_variants).to match_array([mv1, mv2])
    end
  end

  it "has a properly set up model association" do
    model = create(:pens_model)
    mmc = create(:pens_model_micro_cluster, model:)

    expect(mmc.model).to eq(model)
  end
end
