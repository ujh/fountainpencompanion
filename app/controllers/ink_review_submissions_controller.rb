class InkReviewSubmissionsController < ApplicationController
  before_action :authenticate_user!

  def create
    CreateInkReviewSubmission.new(
      user: current_user,
      macro_cluster: macro_cluster,
      url: params[:ink_review_submission][:url]
    ).perform
    head :ok
  end

  private

  def macro_cluster
    MacroCluster.find(params[:ink_id])
  end
end
