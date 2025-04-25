class CreateAgentLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_logs do |t|
      t.string :name, null: false
      t.jsonb :transcript, null: false

      t.timestamps
    end
  end
end
