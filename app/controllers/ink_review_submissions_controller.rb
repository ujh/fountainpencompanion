class InkReviewSubmissionsController < ApplicationController
  before_action :authenticate_user!

  def create
    submission =
      CreateInkReviewSubmission.new(
        user: current_user,
        macro_cluster: macro_cluster,
        url: submission_params[:url]
      ).perform
    if submission.persisted?
      head :ok
    else
      render json: {
               errors: submission.errors.messages.values.flatten
             },
             status: :unprocessable_entity
    end
  end

  private

  attr_reader :macro_cluster

  def macro_cluster
    @macro_cluster ||= MacroCluster.find(params[:ink_id])
  end

  def submission_params
    params[:ink_review_submission] || params.dig(:_jsonapi, :ink_review_submission) || {}
  end
end
