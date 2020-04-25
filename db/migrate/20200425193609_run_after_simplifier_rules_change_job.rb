class RunAfterSimplifierRulesChangeJob < ActiveRecord::Migration[6.0]
  def up
    AfterSimplifierRulesChange.perform_async
  end
end
