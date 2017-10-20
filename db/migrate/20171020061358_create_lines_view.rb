class CreateLinesView < ActiveRecord::Migration[5.1]
  def change
    create_view :lines
  end
end
