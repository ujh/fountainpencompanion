class CreateReadingStatuses < ActiveRecord::Migration[6.0]
  def change
    create_table :reading_statuses do |t|
      t.references :user, foreign_key: true, null: false
      t.references :blog_post, foreign_key: true, null: false
      t.boolean :read, null: false, default: false
      t.boolean :dismissed, null: false, default: false
      t.timestamps
    end
  end
end
