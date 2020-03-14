class MacroClusterSerializer
  include FastJsonapi::ObjectSerializer
  attributes

  has_many :micro_clusters
end
