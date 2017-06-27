class CollectedInk < ApplicationRecord

  KINDS = %w(bottle sample cartridge)

  validates :kind, inclusion: { in: KINDS, allow_blank: true }
  validates :brand_name, length: { in: 1..100 }
  validates :ink_name, length: { in: 1..100 }
  validates :line_name, length: { in: 1..100, allow_blank: true }

  validate :unique_constraint

  belongs_to :user

  def self.field_by_term(field, term, user)
    relation = where("#{field} <> ?", '')
    if user
      relation = relation.where("private = ? OR user_id = ?", false, user.id)
    else
      relation = relation.where(private: false)
    end
    relation.where("LOWER(#{field}) LIKE ?", "#{term.downcase}%").group(field).order(field).pluck(field)
  end

  def self.unique_count
    group("LOWER(brand_name), LOWER(line_name), LOWER(ink_name)").count.size
  end

  def name
    "#{brand_name} #{line_name} #{ink_name}"
  end

  private

  def unique_constraint
    rel = self.class.where(
      "LOWER(brand_name) = ? AND LOWER(line_name) = ? AND LOWER(ink_name) = ?",
      brand_name.to_s.downcase,
      line_name.to_s.downcase,
      ink_name.to_s.downcase
    ).where(user_id: user_id)
    rel = rel.where("id <> ?", id) if persisted?
    errors.add(:ink_name, "Duplicate!") if rel.exists?
  end
end
