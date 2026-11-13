class ErrorReport
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_DESCRIPTION_LENGTH = 2000

  attribute :description, :string

  validates :description, presence: true, length: { maximum: MAX_DESCRIPTION_LENGTH }

  def description=(value)
    super(value.is_a?(String) ? value : nil)
  end
end
