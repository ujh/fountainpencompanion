class MicroCluster < ApplicationRecord
  belongs_to :macro_cluster, optional: true
  has_many :collected_inks

  paginates_per 250
end
