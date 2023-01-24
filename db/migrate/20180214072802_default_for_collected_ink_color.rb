class DefaultForCollectedInkColor < ActiveRecord::Migration[5.1]
  def change
    change_column :collected_inks,
                  :color,
                  :string,
                  limit: 7,
                  default: "",
                  null: false
  end
end
