require "rails_helper"

describe Pens::Model do
  describe "associations" do
    it "has a properly set up model_micro_clusters association" do
      model = create(:pens_model)
      mmc1 = create(:pens_model_micro_cluster, model:)
      mmc2 = create(:pens_model_micro_cluster, model:)

      expect(model.model_micro_clusters).to match_array([mmc1, mmc2])
    end

    it "has a properly set up pen brand association" do
      brand = create(:pens_brand)
      model = create(:pens_model, pens_brand_id: brand.id)

      expect(model.pen_brand).to eq(brand)
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

  describe "embedding_search" do
    it "returns an empty array for a blank query without calling the embeddings client" do
      expect(EmbeddingsClient).not_to receive(:new)

      expect(described_class.embedding_search(nil)).to eq([])
      expect(described_class.embedding_search("")).to eq([])
    end
  end
end
