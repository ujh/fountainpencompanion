class CreateBrands < ActiveRecord::Migration[5.0]
  def change
    create_view :brands
  end
end
