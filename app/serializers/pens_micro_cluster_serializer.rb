class PensMicroClusterSerializer
  include JSONAPI::Serializer

  has_many :collected_pens
  belongs_to :model_variant,
             id_method_name: :pens_model_variant_id,
             serializer: PensModelVariantSerializer

  attribute :simplified_brand
  attribute :simplified_model
  attribute :simplified_color
end
