class UniqueIndexForPenEmbeddings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :pen_embeddings, %i[owner_type owner_id], unique: true, algorithm: :concurrently
  end
end
