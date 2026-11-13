class Admins::ErrorReports::EntriesController < Admins::BaseController
  def create
    error_report = ErrorReport.find(params[:error_report_id])
    entry = error_report.entries.build(entry_params.merge(user: current_user))
    if entry.save
      after_save(entry)
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

  def after_save(entry)
    return unless entry.reply?

    UserMailer.error_report_reply(entry).deliver_later
    entry.error_report.resolve! if params[:resolve] == "1"
  end

  def notice_for(entry)
    entry.reply? ? "Reply sent to #{entry.error_report.user.email}." : "Note added."
  end
end
