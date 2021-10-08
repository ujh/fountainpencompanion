class GutenTagTaggingsIndex < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :gutentag_tags, :taggings_count, algorithm: :concurrently
  end
end
