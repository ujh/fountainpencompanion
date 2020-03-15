class CollectedInkSerializer
  include FastJsonapi::ObjectSerializer

  belongs_to :micro_cluster

  attribute :brand_name
  attribute :line_name
  attribute :ink_name
  attribute :maker
  attribute :color
end
