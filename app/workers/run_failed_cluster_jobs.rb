class UpdateMacroCluster
  include Sidekiq::Worker

  def perform
    run_failed_ink_clusterer_jobs
  end

  private

  def run_failed_ink_clusterer_jobs
    failed_ink_clusterer_jobs.find_each do |log|
      cluster = log.owner
      log.destroy!
      RunInkClustererAgent.perform_async("InkClusterer", cluster.id)
    end
  end

  def failed_ink_clusterer_jobs
    AgentLog.ink_clusterer.processing.where("created_at < ?", 1.hour.ago)
  end
end
