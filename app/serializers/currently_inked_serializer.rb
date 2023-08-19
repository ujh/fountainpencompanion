class CurrentlyInkedSerializer
  include JSONAPI::Serializer

  belongs_to :collected_pen, serializer: CollectedPenSerializer
  belongs_to :collected_ink, serializer: CollectedInkSerializer

  attribute :inked_on
  attribute :archived_on
  attribute :comment
  attribute :last_used_on
  attribute :pen_name
  attribute :ink_name
  attribute :used_today do |object|
    object.used_today?
  end
  attribute :daily_usage do |object|
    v = object.daily_usage_count
    next if v.zero?
    v
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
