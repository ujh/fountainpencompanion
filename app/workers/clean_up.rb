class CleanUp
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  UUID_PATTERN = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$".freeze

  def perform
    remove_unused_accounts
    remove_unconfirmed_accounts
    clear_expired_deletion_requests
    anonymize_sign_up_ip
    reject_orphaned_agent_logs
    remove_orphaned_macro_clusters
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

  # Unlock accounts where deletion was requested more than 24h ago but the account still exists
  def clear_expired_deletion_requests
    User.where("deletion_requested_at < ?", 24.hours.ago).update_all(deletion_requested_at: nil)
  end

  def anonymize_sign_up_ip
    User.where("created_at < ?", 1.month.ago).where.not(sign_up_ip: nil).update_all(sign_up_ip: nil)
  end

  def reject_orphaned_agent_logs
    AgentLog
      .processing
      .where("updated_at < ?", 3.hours.ago)
      .pluck(:id)
      .each { |agent_log_id| CleanUp::RejectAgentLog.perform_async(agent_log_id) }
  end

  # Remove macro clusters that still have the placeholder UUID name from the
  # InkClusterer. They never got any inks, so they never got a real name.
  def remove_orphaned_macro_clusters
    MacroCluster
      .where("macro_clusters.ink_name ~* ?", UUID_PATTERN)
      .where("macro_clusters.created_at < ?", 2.hours.ago)
      .where.not(
        id:
          MicroCluster
            .where.not(macro_cluster_id: nil)
            .joins(:collected_inks)
            .select(:macro_cluster_id)
      )
      .where.not(id: InkReview.select(:macro_cluster_id))
      .where.not(id: InkReviewSubmission.select(:macro_cluster_id))
      .find_each(&:destroy!)
  end
end
