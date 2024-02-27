class AddIndexOnPrivateField < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :collected_inks, :private, algorithm: :concurrently
  end
end
