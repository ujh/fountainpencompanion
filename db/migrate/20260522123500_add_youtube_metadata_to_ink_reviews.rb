class AddYoutubeMetadataToInkReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :ink_reviews, :youtube_tags, :jsonb, default: [], null: false
    add_column :ink_reviews, :youtube_comments, :jsonb, default: [], null: false
    add_column :ink_reviews, :youtube_captions, :text
    add_column :ink_reviews, :youtube_metadata_fetched_at, :datetime
  end
end
