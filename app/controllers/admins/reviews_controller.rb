class Admins::ReviewsController < Admins::BaseController
  def index
    query = InkReview.agent_processed.order("created_at asc")
    @ink_reviews = query.page(params[:page])
    @ink_reviews = query.page(0) if @ink_reviews.empty?

    @stats = calculate_stats
  end

  def destroy
    @ink_review = InkReview.find(params[:id])
    @ink_review.reject!
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

  def calculate_stats
    ids = InkReview.manually_processed.where.not(extra_data: {}).order(created_at: :desc).pluck(:id)
    rel = InkReview.where(id: ids)

    analysis = { total: {}, approved: {}, rejected: {} }

    approved = rel.approved
    approved_correct = approved.where(extra_data: { action: "approve_review" })
    approved_incorrect = approved.where(extra_data: { action: "reject_review" })
    analysis[:approved] = {
      count: approved.count,
      correct: approved_correct.count,
      incorrect: approved_incorrect.count
    }

    rejected = rel.rejected
    rejected_correct = rejected.where(extra_data: { action: "reject_review" })
    rejected_incorrect = rejected.where(extra_data: { action: "approve_review" })
    analysis[:rejected] = {
      count: rejected.count,
      correct: rejected_correct.count,
      incorrect: rejected_incorrect.count
    }

    analysis[:approved].keys.each do |key|
      analysis[:total][key] = analysis[:approved][key] + analysis[:rejected][key]
    end

    %i[total approved rejected].each do |key|
      analysis[key][:correct_percentage] = (
        analysis[key][:correct].to_f / analysis[key][:count].to_f * 100
      ).round(2)
      analysis[key][:incorrect_percentage] = (
        analysis[key][:incorrect].to_f / analysis[key][:count].to_f * 100
      ).round(2)
    end

    analysis
  end
end
