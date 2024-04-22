class PensMicroClusterSerializer
  include JSONAPI::Serializer

  has_many :collected_pens

  attribute :simplified_brand
  attribute :simplified_model
  attribute :simplified_color
  attribute :simplified_material
  attribute :simplified_trim_color
  attribute :simplified_filling_system
end
