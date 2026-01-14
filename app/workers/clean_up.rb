class CleanUp
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  def perform
    remove_unused_accounts
    remove_unconfirmed_accounts
    anonymize_sign_up_ip
    remove_old_user_agents
    reject_orphaned_agent_logs
  end

  private

  # Remove users that have never logged in and created their account more than two years ago
  def remove_unused_accounts
    User
      .where(current_sign_in_at: nil)
      .where("created_at < ?", 2.years.ago)
      .pluck(:id)
      .each { |user_id| CleanUp::DeleteUser.perform_async(user_id) }
  end

  # Remove users that haven't confirmed their email in 4 weeks
  def remove_unconfirmed_accounts
    User
      .where(confirmed_at: nil)
      .where("created_at < ?", 4.weeks.ago)
      .pluck(:id)
      .each { |user_id| CleanUp::DeleteUser.perform_async(user_id) }
  end

  def anonymize_sign_up_ip
    User.where("created_at < ?", 1.month.ago).where.not(sign_up_ip: nil).update_all(sign_up_ip: nil)
  end

  def remove_old_user_agents
    UserAgent
      .where("created_at < ?", 3.hours.ago)
      .in_batches(of: 1000) { |batch| CleanUp::DeleteUserAgents.perform_async(batch.pluck(:id)) }
  end

  def reject_orphaned_agent_logs
    AgentLog
      .processing
      .where("updated_at < ?", 2.days.ago)
      .pluck(:id)
      .each { |agent_log_id| CleanUp::RejectAgentLog.perform_async(agent_log_id) }
  end
end
