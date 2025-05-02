class AddYoutubeShortFlagToInkReview < ActiveRecord::Migration[8.0]
  def change
    add_column :ink_reviews, :you_tube_short, :boolean, default: false
  end
end
