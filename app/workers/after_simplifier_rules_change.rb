class AfterSimplifierRulesChange
  include Sidekiq::Worker

  def perform
    CollectedInk.find_each do |collected_ink|
      macro_cluster_id = collected_ink.micro_cluster.macro_cluster_id
      # Updates the simplifier fields
      collected_ink.save
      AssignMicroCluster.new.perform(collected_ink.id, macro_cluster_id)
    end
  end
end
