class Admins::Agents::InkClustererController < Admins::BaseController
  def index
    @queue_length = agent_logs.count
    @agent_logs = agent_logs.page(params[:page]).per(1)
    @agent_logs = agent_logs.page(0) if @agent_logs.empty?
    @processing =
      @agent_logs.any? do |agent_log|
        agent_log.processing? ||
          (agent_log.extra_data["follow_up_agent"] && !agent_log.extra_data["follow_up_done"])
      end
  end

  def update
    InkClusterer.new(micro_cluster.id).approve!
    redirect_to admins_agents_ink_clusterer_index_path(page: params[:page])
  end

  def destroy
    clusters_to_reprocess = InkClusterer.new(micro_cluster.id).reject!
    clusters_to_reprocess.each do |cluster|
      # Generate a new agent log for the rejected micro cluster
      InkClusterer.new(cluster.id)
      # Now schedule the actual ink clustering job
      RunInkClustererAgent.perform_async("InkClusterer", cluster.id)
    end
    redirect_to admins_agents_ink_clusterer_index_path(page: params[:page])
  end

  private

  def agent_log
    AgentLog.find(params[:id])
  end

  def micro_cluster
    agent_log.owner
  end

  def agent_logs
    AgentLog
      .ink_clusterer
      .where(state: [AgentLog::WAITING_FOR_APPROVAL, AgentLog::PROCESSING])
      .or(AgentLog.ink_clusterer.agent_processed)
      .order(:id)
  end
end
