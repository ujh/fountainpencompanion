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
    if agent_log.agent_approved?
      if agent_log.approved?
        # If agent approved it correctly, we just need to change to manually
        # approved.
        agent_log.approve!
      else
        # If agent rejected it, a follow up action was already taken. We
        # therefore can only change to manually approved. No further action can
        # be taken.
        agent_log.approve!
      end
    else
      InkClusterer.new(micro_cluster.id).approve!
    end
    redirect_to admins_agents_ink_clusterer_index_path(page: params[:page])
  end

  def destroy
    if agent_log.agent_approved?
      if agent_log.approved?
        # If agent approved it, but it needed to be rejected we need to clean
        # up and reprocess.
        reject_and_reprocess!
      else
        # If agent rejected, but should have approved, a follow up action was
        # already taken. So we should only change to manually rejected.
        agent_log.reject!
      end
    else
      reject_and_reprocess!
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

  def reject_and_reprocess!
    clusters_to_reprocess = InkClusterer.new(micro_cluster.id, agent_log_id: agent_log.id).reject!
    clusters_to_reprocess.each do |cluster|
      # Now schedule the actual ink clustering job
      RunInkClustererAgent.perform_async("InkClusterer", cluster.id)
    end
  end
end
