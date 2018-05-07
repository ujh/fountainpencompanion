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
