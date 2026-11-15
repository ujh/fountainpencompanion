class MarkdownComplexityValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if record.errors.include?(attribute)

    if FpcFormatter.too_deeply_nested?(value)
      record.errors.add(attribute, "has too many nested brackets")
    elsif FpcFormatter.too_slow_to_render?(value)
      record.errors.add(attribute, "is too complex to display")
    end
  end
end
