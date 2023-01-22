class LineNameNotNull < ActiveRecord::Migration[5.1]
  def up
    CollectedInk.where("line_name IS NULL").update_all(line_name: "")
    change_column_default :collected_inks, :line_name, ""
    change_column_null :collected_inks, :line_name, false
  end
end
