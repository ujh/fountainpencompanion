class ErrorReportEntry < ApplicationRecord
  KINDS = %w[note reply].freeze
  MAX_BODY_LENGTH = 10_000

  belongs_to :error_report, touch: true
  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }

  def note?
    kind == "note"
  end

  def reply?
    kind == "reply"
  end
end
