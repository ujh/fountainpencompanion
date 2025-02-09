class RemoveEmbeddingsIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :pen_embeddings, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
