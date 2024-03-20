require "csv"

class CollectedPen < ApplicationRecord
  include Archivable
  include PenName

  belongs_to :user
  has_many :currently_inkeds, dependent: :destroy
  has_many :usage_records, through: :currently_inkeds
  has_one :newest_currently_inked,
          -> { order("inked_on desc") },
          class_name: "CurrentlyInked"

  validates :brand, length: { in: 1..100 }
  validates :color, length: { in: 0..100, allow_blank: true }
  validates :model, length: { in: 1..100 }
  validates :nib, length: { in: 1..100, allow_blank: true }

  paginates_per 500
  max_paginates_per 500

  def self.search(field, term)
    results =
      where("#{field} like ?", "%#{term}%").order(field).pluck(field).uniq
    results.length > 100 ? [] : results
  end

  def self.to_csv
    CSV.generate(col_sep: ";") do |csv|
      csv << [
        "Brand",
        "Model",
        "Nib",
        "Color",
        "Material",
        "Trim Color",
        "Filling System",
        "Price",
        "Comment",
        "Archived",
        "Archived On",
        "Usage",
        "Daily Usage",
        "Last Inked",
        "Last Cleaned",
        "Last Used",
        "Inked"
      ]
      all.each do |cp|
        csv << [
          cp.brand,
          cp.model,
          cp.nib,
          cp.color,
          cp.material,
          cp.trim_color,
          cp.filling_system,
          cp.price,
          cp.comment,
          cp.archived?,
          cp.archived_on,
          cp.usage_count,
          cp.daily_usage_count,
          cp.last_inked,
          cp.last_cleaned,
          cp.last_used_on,
          cp.inked?
        ]
      end
    end
  end

  def usage_count
    currently_inkeds.size
  end

  def daily_usage_count
    usage_records.size
  end

  def last_inked
    newest_currently_inked&.inked_on
  end

  def last_cleaned
    newest_currently_inked&.archived_on
  end

  def last_used_on
    newest_currently_inked&.last_used_on || newest_currently_inked&.inked_on
  end

  def inked?
    newest_currently_inked&.active?
  end

  def name
    pen_name_generator(
      brand: brand,
      model: model,
      nib: nib,
      color: color,
      material: material,
      trim_color: trim_color,
      archived: archived?
    )
  end

  def brand=(value)
    super(value.strip)
  end

  def model=(value)
    super(value.strip)
  end

  def nib=(value)
    super(value.strip)
  end

  def color=(value)
    super(value.strip)
  end
end
