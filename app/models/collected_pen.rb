require "csv"

class CollectedPen < ApplicationRecord
  include Archivable
  include PenName

  belongs_to :user
  has_many :currently_inkeds

  validates :brand, length: { in: 1..100 }
  validates :color, length: { in: 0..100, allow_blank: true }
  validates :model, length: { in: 1..100 }
  validates :nib, length: { in: 1..100, allow_blank: true }

  def self.search(field, term)
    where("#{field} like ?", "%#{term}%").order(field).pluck(field).uniq
  end

  def self.to_csv
    CSV.generate(col_sep: ";") do |csv|
      csv << [
        "Brand",
        "Model",
        "Nib",
        "Color",
        "Comment",
        "Archived",
        "Archived On",
        "Usage",
        "Last Inked",
        "Last Cleaned"
      ]
      all.each do |cp|
        usage_count = cp.currently_inkeds.length
        last_inked = nil
        last_cleaned = nil
        if usage_count > 0
          entry = cp.currently_inkeds.order(:inked_on).last
          last_inked = entry.inked_on
          last_cleaned = entry.archived_on
        end
        csv << [
          cp.brand,
          cp.model,
          cp.nib,
          cp.color,
          cp.comment,
          cp.archived?,
          cp.archived_on,
          usage_count,
          last_inked,
          last_cleaned
        ]
      end
    end
  end

  def name
    pen_name_generator(
      brand: brand,
      model: model,
      nib: nib,
      color: color,
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
