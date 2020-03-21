class MacroCluster < ApplicationRecord
  has_many :micro_clusters
  has_many :collected_inks, through: :micro_clusters

  paginates_per 100
end
