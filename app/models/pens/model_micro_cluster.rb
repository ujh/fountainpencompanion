class Pens::ModelMicroCluster < ApplicationRecord
  has_many :model_variants,
           foreign_key: :pens_model_micro_cluster_id,
           class_name: "Pens::ModelVariant",
           dependent: :nullify
end
