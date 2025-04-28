class AddOwnerToAgentLog < ActiveRecord::Migration[8.0]
  def change
    safety_assured { add_reference :agent_logs, :owner, polymorphic: true, index: true }
  end
end
