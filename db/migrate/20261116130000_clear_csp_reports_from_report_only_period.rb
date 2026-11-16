class ClearCspReportsFromReportOnlyPeriod < ActiveRecord::Migration[8.1]
  def up
    safety_assured { execute "DELETE FROM csp_reports" }
  end

  def down
  end
end
