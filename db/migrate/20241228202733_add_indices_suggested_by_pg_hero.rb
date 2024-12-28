class AddIndicesSuggestedByPgHero < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :collected_pens, :user_id, algorithm: :concurrently
    add_index :collected_pens,
              :model,
              using: "gist",
              opclass: :gist_trgm_ops,
              algorithm: :concurrently
    add_index :collected_pens,
              :brand,
              using: "gist",
              opclass: :gist_trgm_ops,
              algorithm: :concurrently
  end
end
