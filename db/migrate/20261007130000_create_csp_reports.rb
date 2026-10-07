class CreateCspReports < ActiveRecord::Migration[8.1]
  def change
    create_table :csp_reports do |t|
      t.string :directive, null: false
      t.string :blocked_uri, null: false
      t.string :page, null: false
      t.integer :count, null: false, default: 1
      t.text :sample
      t.timestamps
    end

    add_index :csp_reports, %i[directive blocked_uri page], unique: true
  end
end
