class CreateCurrentlyInkeds < ActiveRecord::Migration[5.1]
  def change
    create_table :currently_inkeds do |t|
      t.text :comment
      t.string :state
      t.references :collected_ink, foreign_key: true, null: false
      t.references :collected_pen, foreign_key: true, null: false
      t.timestamps
    end
  end
end
