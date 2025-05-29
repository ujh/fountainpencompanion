class AddUsageToAgentLog < ActiveRecord::Migration[8.0]
  def change
    add_column :agent_logs,
               :usage,
               :jsonb,
               default: {
                 prompt_tokens: 0,
                 completion_tokens: 0,
                 total_tokens: 0
               },
               null: false
  end
end
