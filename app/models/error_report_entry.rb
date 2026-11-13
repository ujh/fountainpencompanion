class ErrorReportEntry < ApplicationRecord
  MAX_BODY_LENGTH = 10_000

  belongs_to :error_report, touch: true
  belongs_to :user

  enum :kind, { note: "note", reply: "reply" }, validate: true

  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }
end
