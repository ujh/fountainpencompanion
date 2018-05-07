class UpdateNibInExistingCurrentlyInkedEntries < ActiveRecord::Migration[5.2]
  def change
    CurrentlyInked.archived.find_each do |ci|
      ci.update(nib: ci.collected_pen.nib)
    end
  end
end
