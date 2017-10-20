class UpdateBrandsToVersion2 < ActiveRecord::Migration[5.0]
  def change
    update_view :brands, version: 2, revert_to_version: 1
  end
end
