class AddFullTextSearchToCollectedInks < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    add_column :collected_inks, :tsv, :tsvector
    add_index :collected_inks, :tsv, using: "gin", algorithm: :concurrently

    safety_assured do
      execute <<-SQL
        CREATE TRIGGER tsvectorupdate_ci BEFORE INSERT OR UPDATE
        ON collected_inks FOR EACH ROW EXECUTE PROCEDURE
        tsvector_update_trigger(
          tsv, 'pg_catalog.english', brand_name, line_name, ink_name
        );
      SQL
    end

    now = Time.current.to_s(:db)
    update("UPDATE collected_inks SET updated_at = '#{now}'")
  end

  def down
    safety_assured do
      execute <<-SQL
        DROP TRIGGER tsvectorupdate_ci
        ON collected_inks
      SQL
    end

    remove_index :collected_inks, :tsv
    remove_column :collected_inks, :tsv
  end
end
