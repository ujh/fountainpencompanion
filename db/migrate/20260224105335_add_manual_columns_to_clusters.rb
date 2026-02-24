class AddManualColumnsToClusters < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      change_table :macro_clusters, bulk: true do |t|
        t.string :manual_brand_name, default: ""
        t.string :manual_line_name, default: ""
        t.string :manual_ink_name, default: ""
      end
    end
  end
end
