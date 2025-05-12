class Admins::Agents::InkClusterersController < Admins::BaseController
  def show
    @queue_length = agent_logs.count
    @agent_log = agent_logs.first
    @processing = @agent_log&.processing?

    return unless @agent_log && !@processing
    @processing = true if @agent_log.extra_data["follow_up_agent"] &&
      !@agent_log.extra_data["follow_up_done"]
  end

  def destroy
    InkClusterer.new(next_cluster.id).reject!
    redirect_to admins_agents_ink_clusterer_path
  end

  def update
    InkClusterer.new(next_cluster.id).approve!
    redirect_to admins_agents_ink_clusterer_path
  end

  private

  def agent_logs
    AgentLog
      .ink_clusterer
      .where(state: [AgentLog::WAITING_FOR_APPROVAL, AgentLog::PROCESSING])
      .or(AgentLog.ink_clusterer.agent_processed)
  end
end
