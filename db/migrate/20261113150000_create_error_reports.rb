class CreateErrorReports < ActiveRecord::Migration[8.1]
  def change
    create_table :error_reports do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :reportable, polymorphic: true, null: false
      t.string :reportable_name, null: false
      t.text :description, null: false
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :error_reports,
              :created_at,
              where: "resolved_at IS NULL",
              name: "index_error_reports_open"

    create_table :error_report_entries do |t|
      t.references :error_report, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.text :body, null: false
      t.timestamps
    end
  end
end
