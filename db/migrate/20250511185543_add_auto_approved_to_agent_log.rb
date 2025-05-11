class AddAutoApprovedToAgentLog < ActiveRecord::Migration[8.0]
  def change
    add_column :agent_logs, :agent_approved, :boolean, default: false
  end
end
