class Pens::Brand < ApplicationRecord
  has_many :models,
           foreign_key: :pens_brand_id,
           class_name: "Pens::Model",
           dependent: :nullify
end
