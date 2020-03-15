class MacroCluster < ApplicationRecord
  has_many :micro_clusters

  paginates_per 100
end
