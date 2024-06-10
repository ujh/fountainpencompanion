require "rails_helper"

describe Pens::ModelVariant do
  describe "#search" do
    it "finds model variants by the assigned collected pens" do
      mv1 = create(:pens_model_variant)
      mv2 = create(:pens_model_variant)
      create(
        :collected_pen,
        brand: "TWSBI",
        pens_micro_cluster: create(:pens_micro_cluster, model_variant: mv1)
      )
      create(
        :collected_pen,
        brand: "Other",
        pens_micro_cluster: create(:pens_micro_cluster, model_variant: mv2)
      )

      expect(described_class.search("twsbi")).to eq([mv1])
    end
  end

  describe "associations" do
    it "has a properly set up model micro cluster assiociation" do
      mmc = create(:pens_model_micro_cluster)
      mv = create(:pens_model_variant, model_micro_cluster: mmc)

      expect(mv.model_micro_cluster).to eq(mmc)
    end
  end
end
