class CreateYouTubeChannels < ActiveRecord::Migration[6.1]
  def change
    create_table :you_tube_channels do |t|
      t.string :channel_id, null: false, index: { unique: true }
      t.boolean :back_catalog_imported, default: false

      t.timestamps
    end

    add_column :ink_reviews, :you_tube_channel_id, :bigint
    add_foreign_key :ink_reviews, :you_tube_channels, validate: false
  end
end
