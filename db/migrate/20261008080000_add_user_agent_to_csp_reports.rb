class AddUserAgentToCspReports < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute "DELETE FROM csp_reports"
      add_column :csp_reports, :user_agent, :string, null: false, default: ""
      remove_index :csp_reports, %i[directive blocked_uri page]
      add_index :csp_reports, %i[directive blocked_uri page user_agent], unique: true
    end
  end

  def down
    safety_assured do
      execute "DELETE FROM csp_reports"
      remove_index :csp_reports, %i[directive blocked_uri page user_agent]
      remove_column :csp_reports, :user_agent
      add_index :csp_reports, %i[directive blocked_uri page], unique: true
    end
  end
end
