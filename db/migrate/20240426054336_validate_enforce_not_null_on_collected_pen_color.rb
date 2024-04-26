class ValidateEnforceNotNullOnCollectedPenColor < ActiveRecord::Migration[7.1]
  def up
    validate_check_constraint :collected_pens, name: "collected_pens_color_null"
    change_column_null :collected_pens, :color, false
    remove_check_constraint :collected_pens, name: "collected_pens_color_null"
  end

  def down
    add_check_constraint :collected_pens,
                         "color IS NOT NULL",
                         name: "collected_pens_color_null",
                         validate: false
    change_column_null :collected_pens, :color, true
  end
end
