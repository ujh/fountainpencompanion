# Merges a duplicate macro cluster (source) into another one (target): its
# micro clusters, ink reviews and review submissions move to the target, then
# the source is deleted.
class MergeMacroClusters
  include AfterCommitEverywhere

  def initialize(source, target)
    raise ArgumentError, "Cannot merge macro cluster #{source.id} into itself" if source.id == target.id

    self.source = source
    self.target = target
  end

  def perform
    MacroCluster.transaction do
      source.micro_clusters.update_all(macro_cluster_id: target.id)
      review_mapping = move_ink_reviews
      move_ink_review_submissions(review_mapping)
      target.update!(description: source.description) if target.description.blank?
      source.reload.destroy!
      after_commit { UpdateMacroCluster.perform_async(target.id) }
    end
    target
  end

  private

  attr_accessor :source, :target

  # Returns source review id => target review id for every source review.
  def move_ink_reviews
    source.ink_reviews.to_h do |review|
      existing = target.ink_reviews.find_by(url: review.url)
      if existing
        [review.id, existing.id]
      else
        review.update!(macro_cluster: target)
        [review.id, review.id]
      end
    end
  end

  def move_ink_review_submissions(review_mapping)
    InkReviewSubmission
      .where(macro_cluster_id: source.id)
      .find_each do |submission|
        if duplicate_submission?(submission)
          submission.destroy!
        else
          submission.update!(
            macro_cluster_id: target.id,
            ink_review_id: review_mapping.fetch(submission.ink_review_id, submission.ink_review_id)
          )
        end
      end
  end

  def duplicate_submission?(submission)
    InkReviewSubmission
      .where(macro_cluster_id: target.id, user_id: submission.user_id)
      .where("lower(url) = lower(?)", submission.url)
      .exists?
  end
end
