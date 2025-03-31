class AddVectorIndex < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_index :pen_embeddings, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    end
  end
end
