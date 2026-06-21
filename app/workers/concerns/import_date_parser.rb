module ImportDateParser
  def parse_date(value)
    value.present? ? Date.parse(value) : nil
  rescue Date::Error
    nil
  end
end
