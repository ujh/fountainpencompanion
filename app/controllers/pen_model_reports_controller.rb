class PenModelReportsController < ApplicationController
  include SubmitsErrorReport

  before_action :authenticate_user!

  def create
    submit_error_report(Pens::Model.find(params[:pen_model_id]))
  end
end
