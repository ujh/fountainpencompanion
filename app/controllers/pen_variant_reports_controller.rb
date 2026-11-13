class PenVariantReportsController < ApplicationController
  include SubmitsErrorReport

  before_action :authenticate_user!

  def create
    submit_error_report(Pens::ModelVariant.find(params[:pen_variant_id]))
  end
end
