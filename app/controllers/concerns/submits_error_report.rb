module SubmitsErrorReport
  private

  def submit_error_report(reportable)
    report =
      current_user.error_reports.build(
        reportable: reportable,
        description: report_params[:description]
      )
    if report.save
      head :ok
    else
      render json: { errors: report.errors.full_messages }, status: :unprocessable_content
    end
  end

  def report_params
    params[:_jsonapi].is_a?(ActionController::Parameters) ? params[:_jsonapi] : params
  end
end
