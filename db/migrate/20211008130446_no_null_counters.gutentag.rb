# frozen_string_literal: true
# This migration comes from gutentag (originally 3)

class NoNullCounters < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      change_column :gutentag_tags, :taggings_count, :integer, default: 0, null: false
    end
  end

  def down
    safety_assured do
      change_column :gutentag_tags, :taggings_count, :integer, default: 0, null: true
    end
  end
end
