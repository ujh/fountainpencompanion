class CollectedPenSerializer
  include JSONAPI::Serializer

  belongs_to :pens_micro_cluster
  has_many :currently_inkeds

  attribute :brand
  attribute :model
  attribute :nib
  attribute :color
  attribute :material
  attribute :price
  attribute :trim_color
  attribute :filling_system
  attribute :comment
  attribute :archived do |object|
    object.archived?
  end
  attribute :usage do |object|
    object.usage_count
  end
  attribute :daily_usage do |object|
    object.daily_usage_count
  end
  attribute :last_inked
  attribute :last_cleaned
  attribute :last_used_on
  attribute :inked do |object|
    object.inked?
  end
  attribute :created_at
end
