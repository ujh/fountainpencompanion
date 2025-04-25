class AddExtraDataToAgentLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :agent_logs, :extra_data, :jsonb
  end
end
