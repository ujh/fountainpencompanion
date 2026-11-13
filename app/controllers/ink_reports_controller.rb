class InkReportsController < ApplicationController
  include SubmitsErrorReport

  before_action :authenticate_user!

  def create
    submit_error_report(MacroCluster.find(params[:ink_id]))
  end
end
