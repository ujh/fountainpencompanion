require 'csv'

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
      csv << ["Brand", "Model", "Nib", "Color", "Comment", "Archived", "Archived On", "Usage", "Last Inked"]
      all.each do |cp|
        usage_count = cp.currently_inkeds.length
        last_inked = nil
        last_inked = cp.currently_inkeds.map(&:created_at).max.to_date unless usage_count.zero?
        csv << [
          cp.brand,
          cp.model,
          cp.nib,
          cp.color,
          cp.comment,
          cp.archived?,
          cp.archived_on,
          usage_count,
          last_inked
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

  def deletable?
    currently_inkeds.empty?
  end
end
