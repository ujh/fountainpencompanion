module PenName
  extend ActiveSupport::Concern

  def pen_name_generator(brand:, model:, nib:, color:, archived:)
    n = "#{brand} #{model}"
    n = [n, color, nib].reject { |f| f.blank? }.join(", ")
    n = "#{n} (archived)" if archived
    n
  end
end
