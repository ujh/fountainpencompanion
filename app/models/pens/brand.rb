class Pens::Brand < ApplicationRecord
  has_many :models, foreign_key: :pens_brand_id, class_name: "Pens::Model", dependent: :nullify

  def self.public
    hash = pluck(:id).hash
    ids =
      Rails
        .cache
        .fetch("#{self.class.name}#public-#{hash}", expires_in: 1.hour) do
          joins(models: :collected_pens).group("pens_brands.id").pluck(:id)
        end
    where(id: ids)
  end

  def self.public_count
    public.count
  end

  def public_models
    ids = models.joins(:collected_pens).group("pens_models.id").pluck(:id)
    models.where(id: ids)
  end

  def public_model_count
    public_models.count
  end

  def synonyms
    names - [name]
  end

  def names
    ([name] + models.pluck(:brand)).uniq.sort
  end

  def simplified_names
    names.map { |n| Simplifier.simplify(n) }
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

  def to_param
    "#{id}-#{name.parameterize}"
  end
end
