require "csv"

class UsageRecord < ApplicationRecord
  belongs_to :currently_inked

  paginates_per 100

  validates :used_on, uniqueness: { scope: :currently_inked_id }, presence: true
  validate :used_on_within_currently_inked_range

  delegate :pen_name, :ink_name, :collected_ink, :collected_pen, to: :currently_inked

  def self.to_csv
    CSV.generate(col_sep: ";") do |csv|
      csv << [
        "Used On",
        "Pen Brand",
        "Pen Model",
        "Nib",
        "Pen Colour",
        "Ink Brand",
        "Ink Line",
        "Ink Name",
        "Ink Type",
        "Ink Colour"
      ]
      all.each do |ur|
        csv << [
          ur.used_on,
          ur.collected_pen.brand,
          ur.collected_pen.model,
          (
            if ur.currently_inked.nib.present?
              ur.currently_inked.nib
            else
              ur.collected_pen.nib
            end
          ),
          ur.collected_pen.color,
          ur.collected_ink.brand_name,
          ur.collected_ink.line_name,
          ur.collected_ink.ink_name,
          ur.collected_ink.kind,
          ur.collected_ink.color
        ]
      end
    end
  end

  private

  def used_on_within_currently_inked_range
    return unless used_on && currently_inked

    if used_on < currently_inked.inked_on
      errors.add(:used_on, "cannot be before the currently inked entry was inked")
    elsif used_on > Date.current
      errors.add(:used_on, "cannot be in the future")
    elsif currently_inked.archived? && used_on > currently_inked.archived_on
      errors.add(:used_on, "cannot be after the currently inked entry was archived")
    end
  end
end
