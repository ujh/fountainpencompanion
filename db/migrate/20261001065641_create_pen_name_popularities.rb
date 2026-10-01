class CreatePenNamePopularities < ActiveRecord::Migration[8.1]
  def change
    create_view :pen_name_popularities, materialized: true
    # Unique index is required to refresh the view concurrently. The view was just created, so
    # nothing can be blocked by building the index.
    safety_assured { add_index :pen_name_popularities, %i[field brand_key value_key], unique: true }
  end
end
