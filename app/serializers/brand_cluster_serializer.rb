class BrandClusterSerializer
  include JSONAPI::Serializer

  has_many :macro_clusters

  attribute :name
  attribute :description
  attribute :public_ink_count
end
