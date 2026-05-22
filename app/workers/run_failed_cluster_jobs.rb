class RunFailedClusterJobs
  include Sidekiq::Worker

  def perform
    run_failed_ink_clusterer_jobs
  end

  private

  def run_failed_ink_clusterer_jobs
    failed_ink_clusterer_jobs.find_each do |log|
      RunInkClustererAgent.perform_async("InkClusterer", log.owner_id)
    end
  end

  def failed_ink_clusterer_jobs
    AgentLog.ink_clusterer.processing.where("created_at < ?", 15.minutes.ago)
  end
end
