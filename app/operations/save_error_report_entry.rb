class SaveErrorReportEntry
  def initialize(entry, entry_params, resolve: false)
    self.entry = entry
    self.entry_params = entry_params
    self.resolve = resolve
  end

  def perform
    saved = entry.update(entry_params)
    if saved && entry.reply?
      deliver_reply
      entry.error_report.resolve! if resolve
    end

    saved
  end

  private

  attr_accessor :entry, :entry_params, :resolve

  def deliver_reply
    UserMailer.error_report_reply(entry).deliver_later
  end
end
