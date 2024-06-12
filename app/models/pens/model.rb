class Pens::Model < ApplicationRecord
  has_many :model_micro_clusters,
           foreign_key: :pens_model_id,
           class_name: "Pens::ModelMicroCluster",
           dependent: :nullify
end
