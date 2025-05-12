class Admins::Agents::InkClusterersController < Admins::BaseController
  def show
    @queue_length = MicroCluster.for_cluster_processing.count + agent_logs.count
    @agent_log = agent_logs.first
    @processing = @agent_log&.processing?

    return unless @agent_log && !@processing
    @processing = true if @agent_log.extra_data["follow_up_agent"] &&
      !@agent_log.extra_data["follow_up_done"]
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

  def agent_logs
    AgentLog
      .ink_clusterer
      .where(state: [AgentLog::WAITING_FOR_APPROVAL, AgentLog::PROCESSING])
      .or(AgentLog.ink_clusterer.agent_processed)
  end

  def run_agent!
    cluster = next_cluster
    return unless cluster

    # Adds the agent_log to the system if it does not exist, yet
    InkClusterer.new(cluster.id)
    RunAgent.perform_async("InkClusterer", cluster.id)
  end
end
