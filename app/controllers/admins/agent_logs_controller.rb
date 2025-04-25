class Admins::AgentLogsController < Admins::BaseController
  def index
    @agent_logs = AgentLog.order("created_at desc").page(params[:page]).per(1)
  end
end
