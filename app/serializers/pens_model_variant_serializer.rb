class PensModelVariantSerializer
  include JSONAPI::Serializer

  has_many :micro_clusters, serializer: PensMicroClusterSerializer

  attribute :brand
  attribute :model
  attribute :color
  attribute :material
  attribute :trim_color
  attribute :filling_system
end
