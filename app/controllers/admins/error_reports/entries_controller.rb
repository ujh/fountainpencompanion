class Admins::ErrorReports::EntriesController < Admins::BaseController
  def create
    error_report = ErrorReport.find(params[:error_report_id])
    entry = error_report.entries.build(user: current_user)
    if SaveErrorReportEntry.new(entry, entry_params, resolve: params[:resolve] == "1").perform
      redirect_to admins_error_report_path(error_report), notice: notice_for(entry)
    else
      redirect_to admins_error_report_path(error_report),
                  alert: entry.errors.full_messages.to_sentence
    end
  end

  private

  def entry_params
    params.require(:error_report_entry).permit(:kind, :body)
  end

  def notice_for(entry)
    entry.reply? ? "Reply sent to #{entry.error_report.user.email}." : "Note added."
  end
end
