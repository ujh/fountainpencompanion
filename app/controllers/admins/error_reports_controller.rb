class Admins::ErrorReportsController < Admins::BaseController
  STATUSES = %w[open resolved all].freeze

  add_breadcrumb "Reports", :admins_error_reports_path

  def index
    @status = STATUSES.include?(params[:status]) ? params[:status] : "open"
    @counts = status_counts
    @error_reports =
      filtered_reports
        .includes(:user, :entries)
        .order(created_at: :desc)
        .page(params[:page])
        .per(50)
  end

  def show
    @error_report = ErrorReport.find(params[:id])
    add_breadcrumb "#{@error_report.kind} report ##{@error_report.id}",
                   admins_error_report_path(@error_report)
  end

  def update
    error_report = ErrorReport.find(params[:id])
    case params[:resolved]
    when "true"
      error_report.resolve!
    when "false"
      error_report.reopen!
    else
      return head :bad_request
    end
    redirect_to admins_error_report_path(error_report)
  end

  private

  def status_counts
    open = ErrorReport.open.count
    resolved = ErrorReport.resolved.count
    { "open" => open, "resolved" => resolved, "all" => open + resolved }
  end

  def filtered_reports
    case @status
    when "open"
      ErrorReport.open
    when "resolved"
      ErrorReport.resolved
    else
      ErrorReport.all
    end
  end
end
