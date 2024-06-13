class PensModelSerializer
  include JSONAPI::Serializer

  has_many :model_micro_clusters, serializer: PensModelMicroClusterSerializer

  attribute :brand
  attribute :model
end
