class RerunMacroClusterJobs < ActiveRecord::Migration[6.0]
  def change
    MacroCluster.find_each {|c| UpdateMacroCluster.perform_async(c.id) }
  end
end
