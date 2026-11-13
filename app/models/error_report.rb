class ErrorReport < ApplicationRecord
  MAX_DESCRIPTION_LENGTH = 2000

  KINDS = {
    "InkReview" => "Review",
    "MacroCluster" => "Ink",
    "Pens::Model" => "Pen model",
    "Pens::ModelVariant" => "Pen variant"
  }.freeze

  belongs_to :user
  belongs_to :reportable, polymorphic: true, optional: true
  has_many :entries, -> { order(:created_at, :id) }, class_name: "ErrorReportEntry"

  validates :reportable, presence: true, on: :create
  validates :reportable_type, inclusion: { in: KINDS.keys }
  validates :description, presence: true, length: { maximum: MAX_DESCRIPTION_LENGTH }

  before_validation :set_reportable_name, on: :create

  scope :open, -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }

  def description=(value)
    super(value.is_a?(String) ? value : nil)
  end

  def kind
    KINDS.fetch(reportable_type)
  end

  def resolved?
    resolved_at.present?
  end

  def resolve!
    update!(resolved_at: Time.current) unless resolved?
  end

  def reopen!
    update!(resolved_at: nil)
  end

  private

  def set_reportable_name
    self.reportable_name =
      case reportable
      when InkReview
        "#{reportable.title} (review of #{reportable.macro_cluster.name})"
      when nil
        nil
      else
        reportable.name
      end
  end
end
