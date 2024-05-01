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
end
