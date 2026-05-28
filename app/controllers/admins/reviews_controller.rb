class Admins::ReviewsController < Admins::BaseController
  def index
    query = InkReview.agent_processed.includes(:agent_logs).order("created_at asc")
    @ink_reviews = query.page(params[:page])
    @ink_reviews = query.page(0) if @ink_reviews.empty?

    @stats = calculate_stats
  end

  def destroy
    @ink_review = InkReview.find(params[:id])
    @ink_review.reject!
    if params[:ignore_youtube_channel] && @ink_review.you_tube_channel.present?
      @ink_review.you_tube_channel.update(ignored: true)
    end
    redirect_after_change
  end

  def update
    @ink_review = InkReview.find(params[:id])
    @ink_review.approve!
    redirect_after_change
  end

  private

  def redirect_after_change
    if request.referrer.blank? || request.referrer =~ %r{/admins}
      redirect_to admins_reviews_path(page: params[:page])
    else
      redirect_to request.referrer
    end
  end

  STATS_WINDOW = 6.months

  def calculate_stats
    cutoff = STATS_WINDOW.ago
    rel =
      InkReview
        .manually_processed
        .where.not(extra_data: {})
        .where("approved_at >= :cutoff OR rejected_at >= :cutoff", cutoff: cutoff)

    analysis = {}
    analysis[:total] = stats_for(rel)

    actions = rel.distinct.pluck(Arel.sql("extra_data->>'action'")).compact.sort
    actions.each { |action| analysis[action] = stats_for(rel, agent_action: action) }

    analysis[:agent_submitted] = stats_for_agent_submitted(rel)
    analysis
  end

  def stats_for(rel, agent_action: nil)
    scope = agent_action ? rel.where("extra_data->>'action' = ?", agent_action) : rel
    approved = scope.approved.count
    rejected = scope.rejected.count
    count = approved + rejected

    case agent_action
    when "approve_review"
      correct = approved
      incorrect = rejected
    when "reject_review"
      correct = rejected
      incorrect = approved
    else
      correct =
        scope.approved.where("extra_data->>'action' = ?", "approve_review").count +
          scope.rejected.where("extra_data->>'action' = ?", "reject_review").count
      incorrect = count - correct
    end

    { count: count, correct: correct, incorrect: incorrect }.merge(
      percentages(count, correct, incorrect)
    )
  end

  def stats_for_agent_submitted(rel)
    agent_submitted =
      rel.joins(:ink_review_submissions).where(
        ink_review_submissions: {
          user: User.find_by(email: "urban@bettong.net")
        }
      )
    count = agent_submitted.count
    correct = agent_submitted.approved.count
    incorrect = agent_submitted.rejected.count
    { count: count, correct: correct, incorrect: incorrect }.merge(
      percentages(count, correct, incorrect)
    )
  end

  def percentages(count, correct, incorrect)
    return { correct_percentage: 0.0, incorrect_percentage: 0.0 } if count.zero?
    {
      correct_percentage: correct.to_f / count * 100,
      incorrect_percentage: incorrect.to_f / count * 100
    }
  end
end
