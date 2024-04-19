class Pens::MicroCluster < ApplicationRecord
  has_many :collected_pens, foreign_key: :pens_micro_cluster
end
