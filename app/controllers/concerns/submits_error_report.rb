module SubmitsErrorReport
  private

  def submit_error_report
    report = ErrorReport.new(description: report_params[:description])
    if report.valid?
      yield report.description
      head :ok
    else
      render json: { errors: report.errors.full_messages }, status: :unprocessable_content
    end
  end

  def report_params
    params[:_jsonapi].is_a?(ActionController::Parameters) ? params[:_jsonapi] : params
  end
end
