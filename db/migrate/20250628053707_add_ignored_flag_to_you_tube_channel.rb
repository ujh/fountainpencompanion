class AddIgnoredFlagToYouTubeChannel < ActiveRecord::Migration[8.0]
  def change
    add_column :you_tube_channels, :ignored, :boolean, default: false
  end
end
