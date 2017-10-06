class PopulateSimplifiedFields < ActiveRecord::Migration[5.1]
  def up
    # Calling save runs the simplifier
    CollectedInk.all.map(&:save!)
  end
end
