class PenVariantReportsController < ApplicationController
  include SubmitsErrorReport

  before_action :authenticate_user!

  def create
    pen_variant = Pens::ModelVariant.find(params[:pen_variant_id])
    submit_error_report do |description|
      AdminMailer.pen_variant_report(pen_variant, current_user, description).deliver_later
    end
  end
end
