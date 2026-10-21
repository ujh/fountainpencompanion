# Merges a duplicate macro cluster (source) into another one (target): its
# micro clusters, ink reviews and review submissions move to the target, then
# the source is deleted.
#
# Known limit: an InkClusterer (schedule_follow_up!) or CheckInkClustering::Assign
# run in flight during a merge can write the source's id back as the log's
# cluster_id.
class MergeMacroClusters
  include AfterCommitEverywhere

  def initialize(source, target)
    if source.id == target.id
      raise ArgumentError, "Cannot merge macro cluster #{source.id} into itself"
    end

    self.source = source
    self.target = target
  end

  def perform
    MacroCluster.transaction do
      [source, target].sort_by(&:id).each(&:lock!)
      source.micro_clusters.update_all(macro_cluster_id: target.id)
      retire_create_approvals
      move_ink_reviews
      move_ink_review_submissions
      repoint_pending_assignments
      copy_details
      source.reload.destroy!
      after_commit { UpdateMacroCluster.perform_async(target.id) }
    end
    target
  end

  private

  attr_accessor :source, :target

  def move_ink_reviews
    source.ink_reviews.each do |review|
      existing = target.ink_reviews.find_by(url: review.url)
      if existing.nil?
        review.update!(macro_cluster: target)
      elsif preferred?(review, existing)
        replace_review(existing, review)
        review.update!(macro_cluster: target)
      else
        replace_review(review, existing)
      end
    end
  end

  def preferred?(review, existing)
    standing(review) > standing(existing)
  end

  def standing(review)
    return 0 unless review.approved?

    review.check_count.zero? ? 2 : 1
  end

  def replace_review(dropped, kept)
    InkReviewSubmission.where(ink_review_id: dropped.id).update_all(ink_review_id: kept.id)
    dropped.destroy!
  end

  def move_ink_review_submissions
    submissions = InkReviewSubmission.where(macro_cluster_id: source.id)
    submissions.where(<<~SQL, target.id).delete_all
      EXISTS (
        SELECT 1 FROM ink_review_submissions existing
        WHERE existing.macro_cluster_id = ?
          AND existing.user_id = ink_review_submissions.user_id
          AND lower(existing.url) = lower(ink_review_submissions.url)
      )
    SQL
    submissions.update_all(macro_cluster_id: target.id)
  end

  def repoint_pending_assignments
    AgentLog
      .ink_clusterer
      .where(state: [AgentLog::PROCESSING, AgentLog::WAITING_FOR_APPROVAL])
      .where("extra_data->>'action' = 'assign_to_cluster'")
      .where("extra_data->>'cluster_id' = ?", source.id.to_s)
      .update_all(
        ["extra_data = jsonb_set(extra_data, '{cluster_id}', to_jsonb(?::bigint))", target.id]
      )
  end

  def retire_create_approvals
    AgentLog
      .ink_clusterer
      .approved
      .where(
        agent_approved: true,
        owner_type: "MicroCluster",
        owner_id: target.micro_clusters.select(:id)
      )
      .where("extra_data->>'action' = 'create_new_cluster'")
      .update_all(
        [
          "agent_approved = false, extra_data = extra_data || jsonb_build_object('merged_into', ?::bigint)",
          target.id
        ]
      )
  end

  def copy_details
    target.description = source.description if target.description.blank?
    target.brand_cluster_id ||= source.brand_cluster_id
    target.save!
  end
end
