class AddDefaultToCollectedPensColor < ActiveRecord::Migration[7.1]
  def change
    change_column_default :collected_pens, :color, from: nil, to: ""
  end
end
