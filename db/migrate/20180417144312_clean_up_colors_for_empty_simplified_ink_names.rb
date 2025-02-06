class CleanUpColorsForEmptySimplifiedInkNames < ActiveRecord::Migration[5.2]
  def change
    # This is bogus data. Better to remove it all. Use save here to also recalculate the
    # simplified fields at the same time.
    CollectedInk.where(simplified_ink_name: "").find_each { |ci| ci.update(color: "") }
  end
end
