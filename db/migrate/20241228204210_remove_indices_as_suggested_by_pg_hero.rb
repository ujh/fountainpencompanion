class RemoveIndicesAsSuggestedByPgHero < ActiveRecord::Migration[8.0]
  def change
    remove_index :collected_inks,
                 name: "index_collected_inks_on_archived_on",
                 column: :archived_on
    remove_index :gutentag_taggings,
                 name:
                   "index_gutentag_taggings_on_taggable_type_and_taggable_id",
                 column: %i[taggable_type taggable_id]
    remove_index :leader_board_rows,
                 name: "index_leader_board_rows_on_type",
                 column: :type
    remove_index :usage_records,
                 name: "index_usage_records_on_currently_inked_id",
                 column: :currently_inked_id
  end
end
