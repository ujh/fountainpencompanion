class SetColorDefaultForCollectedPens < ActiveRecord::Migration[7.1]
  def change
    CollectedPen.where(color: nil).update_all(color: "")
  end
end
