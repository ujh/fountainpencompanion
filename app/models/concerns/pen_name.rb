module PenName
  extend ActiveSupport::Concern

  def pen_name_generator(
    brand:,
    model:,
    nib:,
    color:,
    material:,
    trim_color:,
    archived:
  )
    n = "#{brand} #{model}"
    n = [n, color, material, trim_color, nib].reject { |f| f.blank? }.join(", ")
    n = "#{n} (archived)" if archived
    n
  end
end
