class AdjustIndicesAsSuggestedByPgHero < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :ink_embeddings,
                 name: "index_ink_embeddings_on_owner",
                 column: %i[owner_type owner_id]
    remove_index :pen_embeddings,
                 name: "index_pen_embeddings_on_owner",
                 column: %i[owner_type owner_id]

    add_index :collected_inks, %i[user_id brand_name], algorithm: :concurrently
    add_index :ink_embeddings, [:owner_id], algorithm: :concurrently
    add_index :pen_embeddings, [:owner_id], algorithm: :concurrently
    add_index :user_agents, [:day], algorithm: :concurrently
    add_index :versions, [:whodunnit], algorithm: :concurrently
  end
end
