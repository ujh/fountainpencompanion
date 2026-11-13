class InkReportsController < ApplicationController
  include SubmitsErrorReport

  before_action :authenticate_user!

  def create
    ink = MacroCluster.find(params[:ink_id])
    submit_error_report do |description|
      AdminMailer.ink_report(ink, current_user, description).deliver_later
    end
  end
end
