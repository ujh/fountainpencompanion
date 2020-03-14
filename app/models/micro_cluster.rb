class MicroCluster < ApplicationRecord
  belongs_to :macro_cluster, optional: true
end
