class CreateUserAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :user_agents do |t|
      t.string :name
      t.string :raw_name
      t.date :day

      t.index %i[name day]
      t.timestamps
    end
  end
end
