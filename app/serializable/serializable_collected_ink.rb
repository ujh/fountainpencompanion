class SerializableCollectedInk < JSONAPI::Serializable::Resource
  type 'collected_inks'

  attribute :archived do
    @object.archived?
  end
  attribute :archived_on
  attribute :brand_name
  attribute :color
  attribute :comment
  attribute :deletable do
    @object.deletable?
  end
  attribute :ink_id do
    @object.micro_cluster&.macro_cluster_id
  end
  attribute :ink_name
  attribute :kind
  attribute :line_name
  attribute :maker
  attribute :private
  attribute :private_comment
  attribute :simplified_brand_name
  attribute :simplified_ink_name
  attribute :simplified_line_name
  attribute :swabbed
  attribute :usage do
    @object.currently_inked_count
  end
  attribute :daily_usage do
    @object.usage_records.size
  end
  attribute :used
end
