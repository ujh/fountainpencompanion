class CollectedInkSerializer
  include FastJsonapi::ObjectSerializer
  attributes

  belongs_to :micro_cluster
end
