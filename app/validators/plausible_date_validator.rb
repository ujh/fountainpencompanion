class PlausibleDateValidator < ActiveModel::EachValidator
  EARLIEST = Date.new(1900, 1, 1)

  def self.latest = Date.current.next_year

  def validate_each(record, attribute, value)
    return if value.blank?
    return if value.between?(EARLIEST, self.class.latest)

    record.errors.add(attribute, "must be between #{EARLIEST} and #{self.class.latest}")
  end
end
