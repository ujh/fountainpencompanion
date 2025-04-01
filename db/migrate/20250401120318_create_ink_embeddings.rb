class CreateInkEmbeddings < ActiveRecord::Migration[8.0]
  def change
    create_table :ink_embeddings do |t|
      t.text :content, null: false
      t.vector :embedding, limit: 1536, index: { using: :hnsw, opclass: :vector_cosine_ops }
      t.references :owner, polymorphic: true, null: false
      t.index %i[owner_type owner_id], unique: true
      t.timestamps
    end
  end
end
