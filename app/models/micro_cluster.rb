class MicroCluster < ApplicationRecord
  belongs_to :macro_cluster, optional: true
  has_many :collected_inks

  paginates_per 100

  scope :unassigned, -> { where(macro_cluster_id: nil) }
  scope :without_ignored, -> { where(ignored: false) }
  scope :ignored, -> { where(ignored: true) }
end
