class UpdatePenNamePopularitiesToVersion2 < ActiveRecord::Migration[8.1]
  def change
    # Builds the new version next to the old one, so reads aren't interrupted
    update_view :pen_name_popularities,
                version: 2,
                revert_to_version: 1,
                materialized: {
                  side_by_side: true
                }
  end
end
