class RefreshInkClusters
  include Sidekiq::Worker

  def perform
    MacroCluster.find_each { |c| UpdateMacroCluster.perform_async(c.id) }
  end
end
