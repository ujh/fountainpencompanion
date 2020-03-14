class MicroClusterSerializer
  include FastJsonapi::ObjectSerializer
  attributes

  belongs_to :macro_cluster
  has_many :collected_inks
end
