class PenModelReportsController < ApplicationController
  include SubmitsErrorReport

  before_action :authenticate_user!

  def create
    pen_model = Pens::Model.find(params[:pen_model_id])
    submit_error_report do |description|
      AdminMailer.pen_model_report(pen_model, current_user, description).deliver_later
    end
  end
end
