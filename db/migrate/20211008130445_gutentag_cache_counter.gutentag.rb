# frozen_string_literal: true
# This migration comes from gutentag (originally 2)

class GutentagCacheCounter < ActiveRecord::Migration[6.1]
  def up
    add_column :gutentag_tags, :taggings_count, :integer, default: 0

    Gutentag::Tag.reset_column_information
    Gutentag::Tag
      .pluck(:id)
      .each { |tag_id| Gutentag::Tag.reset_counters tag_id, :taggings }
  end

  def down
    remove_column :gutentag_tags, :taggings_count
  end
end
