class AddCounterCacheForCollectedInksAndCurrentlyInkeds < ActiveRecord::Migration[5.2]
  def change
    add_column :collected_inks, :currently_inked_count, :integer, default: 0
    CollectedInk.reset_column_information
    CollectedInk.find_each { |ci| CollectedInk.reset_counters ci.id, :currently_inkeds }
  end
end
