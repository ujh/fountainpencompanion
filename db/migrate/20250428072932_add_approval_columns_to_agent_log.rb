class AddApprovalColumnsToAgentLog < ActiveRecord::Migration[8.0]
  def change
    add_column :agent_logs, :approved_at, :timestamp
    add_column :agent_logs, :rejected_at, :timestamp
  end
end
