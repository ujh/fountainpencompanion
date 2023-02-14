class CurrentlyInkedSerializer
  include JSONAPI::Serializer

  belongs_to :collected_pen, serializer: CollectedPenSerializer
  belongs_to :collected_ink, serializer: CollectedInkSerializer

  attribute :inked_on
  attribute :archived_on
  attribute :comment
  attribute :last_used_on
  attribute :daily_usage do |object|
    object.daily_usage_count
  end
  attribute :refillable do |object|
    object.refillable?
  end
  attribute :unarchivable do |object|
    object.unarchivable?
  end
  attribute :archived do |object|
    object.archived?
  end
end
