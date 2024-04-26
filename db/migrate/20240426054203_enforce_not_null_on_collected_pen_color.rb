class EnforceNotNullOnCollectedPenColor < ActiveRecord::Migration[7.1]
  def change
    add_check_constraint :collected_pens,
                         "color IS NOT NULL",
                         name: "collected_pens_color_null",
                         validate: false
  end
end
