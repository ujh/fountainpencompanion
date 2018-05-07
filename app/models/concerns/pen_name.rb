module PenName

  extend ActiveSupport::Concern

  def pen_name_generator(brand:, model:, nib:, color:, archived: )
    n = [brand, model, nib, color].reject {|f| f.blank?}.join(' ')
    n = "#{n} (archived)" if archived
    n
  end

end
