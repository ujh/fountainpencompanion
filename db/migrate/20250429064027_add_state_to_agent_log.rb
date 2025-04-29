class AddStateToAgentLog < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :agent_logs, :state, :string, default: "processing"
      add_index :agent_logs, :state
    end
  end
end
