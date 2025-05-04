class Admins::AgentLogsController < Admins::BaseController
  def index
    relation = AgentLog.order("created_at desc")
    relation = relation.where(name: params[:name]) if params[:name].present?
    @agent_logs = relation.page(params[:page]).per(1)
    @agent_log_names = agent_log_names
  end

  private

  def agent_log_names
    AgentLog.group(:name).count.map { |k, v| ["#{k} (#{v})", k] }.to_h
  end
end
