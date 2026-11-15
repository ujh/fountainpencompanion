class MarkdownNestingValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless FpcFormatter.too_deeply_nested?(value)

    record.errors.add(attribute, "has too many nested brackets")
  end
end
