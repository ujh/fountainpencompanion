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
    include HnswEfSearchHelpers

    let(:query_embedding) { Array.new(1536) { |i| i.zero? ? 1.0 : 0.0 } }
    let(:embeddings_client) { instance_double(EmbeddingsClient, fetch: query_embedding) }

    before { allow(EmbeddingsClient).to receive(:new).and_return(embeddings_client) }

    it "returns an empty array for a blank query without calling the embeddings client" do
      expect(EmbeddingsClient).not_to receive(:new)

      expect(described_class.embedding_search(nil)).to eq([])
      expect(described_class.embedding_search("")).to eq([])
    end

    it "returns the models closest to the query" do
      model = create(:pens_model)
      PenEmbedding.create!(owner: model, content: "safari", embedding: query_embedding)

      results = described_class.embedding_search("safari")

      expect(embeddings_client).to have_received(:fetch).with("safari")
      expect(results.map(&:owner)).to eq([model])
      expect(results.first.distance).to be_within(0.0001).of(0)
    end

    it "runs every nearest neighbour query with ef_search set to 1000" do
      values =
        hnsw_ef_search_during_nearest_neighbor_queries do
          described_class.embedding_search("safari")
        end

      expect(values).to eq(%w[1000 1000 1000])
    end

    context "without transactional tests" do
      self.use_transactional_tests = false

      it "fetches the embedding outside a transaction" do
        transaction_open_at_fetch = nil
        allow(embeddings_client).to receive(:fetch) do
          transaction_open_at_fetch = ActiveRecord::Base.connection.transaction_open?
          query_embedding
        end

        described_class.embedding_search("safari")

        expect(transaction_open_at_fetch).to be(false)
      end

      it "does not leave ef_search set on the connection" do
        described_class.embedding_search("safari")

        expect(hnsw_ef_search).not_to eq("1000")
      end
    end
  end
end
