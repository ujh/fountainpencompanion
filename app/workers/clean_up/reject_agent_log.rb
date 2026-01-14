class CleanUp::RejectAgentLog
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  def perform(agent_log_id)
    agent_log = AgentLog.find_by(id: agent_log_id)
    agent_log.reject! if agent_log && agent_log.processing?
  end
end
