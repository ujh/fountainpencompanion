class CollectedInkSerializer
  include JSONAPI::Serializer

  belongs_to :micro_cluster
  has_many :tags

  attribute :brand_name
  attribute :line_name
  attribute :ink_name
  attribute :maker
  attribute :color

  attribute :archived_on
  attribute :comment
  attribute :kind
  attribute :private
  attribute :private_comment
  attribute :simplified_brand_name
  attribute :simplified_ink_name
  attribute :simplified_line_name
  attribute :swabbed
  attribute :used
  attribute :archived do |object|
    object.archived?
  end
  attribute :deletable do |object|
    object.deletable?
  end
  attribute :ink_id do |object|
    object.micro_cluster&.macro_cluster_id
  end
  attribute :usage do |object|
    object.currently_inked_count
  end
  attribute :daily_usage do |object|
    object.usage_records.size
  end
end
