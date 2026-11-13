class SaveErrorReportEntry
  def initialize(entry, entry_params, resolve: false)
    self.entry = entry
    self.entry_params = entry_params
    self.resolve = resolve
  end

  def perform
    saved = entry.update(entry_params)
    reply_to_reporter if saved && entry.reply?

    saved
  end

  private

  attr_accessor :entry, :entry_params, :resolve

  def reply_to_reporter
    UserMailer.error_report_reply(entry).deliver_later
    entry.error_report.resolve! if resolve
  end
end
