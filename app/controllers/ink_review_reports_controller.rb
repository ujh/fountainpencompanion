class InkReviewReportsController < ApplicationController
  include SubmitsErrorReport

  before_action :authenticate_user!

  def create
    submit_error_report(InkReview.live.find(params[:ink_review_id]))
  end
end
