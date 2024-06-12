class PensModelVariantSerializer
  include JSONAPI::Serializer

  has_many :micro_clusters, serializer: PensMicroClusterSerializer
  belongs_to :model_micro_cluster,
             serializer: PensModelMicroClusterSerializer,
             id_method_name: :pens_model_micro_cluster_id

  attribute :brand
  attribute :model
  attribute :color
  attribute :material
  attribute :trim_color
  attribute :filling_system
end
