class UpdateInksToVersion3 < ActiveRecord::Migration[5.0]
  def change
    update_view :inks, version: 3, revert_to_version: 2
  end
end
