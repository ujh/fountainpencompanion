require "rails_helper"

describe Pens::Model do
  describe "associations" do
    it "has a properly set up model_micro_clusters association" do
      model = create(:pens_model)
      mmc1 = create(:pens_model_micro_cluster, model:)
      mmc2 = create(:pens_model_micro_cluster, model:)

      expect(model.model_micro_clusters).to match_array([mmc1, mmc2])
    end
  end

  describe "search" do
    it "finds the model by the associated model variants" do
      m1 = create(:pens_model)
      create(
        :pens_model_variant,
        brand: "Brand One",
        model_micro_cluster: create(:pens_model_micro_cluster, model: m1)
      )
      m2 = create(:pens_model)
      create(
        :pens_model_variant,
        brand: "Brand Two",
        model_micro_cluster: create(:pens_model_micro_cluster, model: m2)
      )

      expect(described_class.search("two")).to eq([m2])
    end
  end
end
