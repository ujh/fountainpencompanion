class Pens::Brand < ApplicationRecord
  has_many :models,
           foreign_key: :pens_brand_id,
           class_name: "Pens::Model",
           dependent: :nullify

  def synonyms
    names - [name]
  end

  def names
    ([name] + models.pluck(:brand)).uniq.sort
  end

  def update_name!
    grouped =
      models
        .pluck(:brand)
        .map { |n| n.gsub("’", "'").gsub(/\(.*\)/, "").strip }
        .group_by(&:itself)
        .transform_values(&:count)
    update!(name: grouped.max_by(&:last).first)
  end
end
