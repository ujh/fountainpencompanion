class InkReviewSubmissionsController < ApplicationController
  before_action :authenticate_user!

  def create
    submission =
      CreateInkReviewSubmission.new(
        user: current_user,
        macro_cluster: macro_cluster,
        url: params[:ink_review_submission][:url]
      ).perform
    if submission.persisted?
      head :ok
    else
      render json: { errors: submission.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def macro_cluster
    MacroCluster.find(params[:ink_id])
  end
end
