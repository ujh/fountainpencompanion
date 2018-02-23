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
  attribute :ink_name
  attribute :kind
  attribute :line_name
  attribute :private
  attribute :simplified_brand_name
  attribute :simplified_ink_name
  attribute :simplified_line_name
  attribute :swabbed
  attribute :used

end
