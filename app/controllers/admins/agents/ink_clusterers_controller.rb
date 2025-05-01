class Admins::Agents::InkClusterersController < Admins::BaseController
  def show
    @queue_length = MicroCluster.for_cluster_processing.count
    @agent_log =
      AgentLog
        .ink_clusterer
        .where(state: [AgentLog::WAITING_FOR_APPROVAL, AgentLog::PROCESSING])
        .first
    @processing = @agent_log&.processing?
  end

  def create
    run_agent!
    redirect_to admins_agents_ink_clusterer_path
  end

  def destroy
    InkClusterer.new(next_cluster.id).reject!
    run_agent!
    redirect_to admins_agents_ink_clusterer_path
  end

  def update
    InkClusterer.new(next_cluster.id).approve!
    run_agent!
    redirect_to admins_agents_ink_clusterer_path
  end

  private

  def next_cluster
    MicroCluster.for_cluster_processing.first
  end

  def run_agent!
    cluster = next_cluster
    return unless cluster

    # Adds the agent_log to the system if it does not exist, yet
    InkClusterer.new(cluster.id)
    RunAgent.perform_async("InkClusterer", cluster.id)
  end

  def processing?
    AgentLog.ink_clusterer.processing.any?
  end
end
