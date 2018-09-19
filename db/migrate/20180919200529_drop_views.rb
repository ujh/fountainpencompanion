class DropViews < ActiveRecord::Migration[5.2]
  def change
    drop_view :brands, revert_to_version: 2
    drop_view :lines, revert_to_version: 1
    drop_view :inks, revert_to_version: 3
  end
end
