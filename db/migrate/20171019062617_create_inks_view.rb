class CreateInksView < ActiveRecord::Migration[5.1]
  def change
    create_view :inks
  end
end
