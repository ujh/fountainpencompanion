class ValidateCreateYouTubeChannels < ActiveRecord::Migration[6.1]
  def change
    validate_foreign_key :ink_reviews, :you_tube_channels
  end
end
