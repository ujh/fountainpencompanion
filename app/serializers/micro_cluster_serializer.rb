class MicroClusterSerializer
  include JSONAPI::Serializer

  belongs_to :macro_cluster
  has_many :collected_inks

  attribute :simplified_brand_name
  attribute :simplified_line_name
  attribute :simplified_ink_name
end
