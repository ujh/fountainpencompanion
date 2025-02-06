class PensModelMicroClusterSerializer
  include JSONAPI::Serializer

  has_many :model_variants, serializer: PensModelVariantSerializer
  belongs_to :model, id_method_name: :pens_model_id, serializer: PensModelSerializer

  attribute :simplified_brand
  attribute :simplified_model
end
