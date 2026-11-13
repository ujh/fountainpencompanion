class InkReviewReportsController < ApplicationController
  include SubmitsErrorReport

  before_action :authenticate_user!

  def create
    ink_review = InkReview.live.find(params[:ink_review_id])
    submit_error_report do |description|
      AdminMailer.ink_review_report(ink_review, current_user, description).deliver_later
    end
  end
end
