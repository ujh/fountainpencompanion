class Admins::CspReportsController < Admins::BaseController
  def index
    @csp_reports = CspReport.order(updated_at: :desc).page(params[:page]).per(100)
  end
end
