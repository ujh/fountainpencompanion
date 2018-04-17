class Simplifier

  def self.simplify(name)
    without_brackets = name.gsub(/\(.*\)/, '')
    without_hashtag_number = without_brackets.gsub(/^#?\d+/, '')
    without_no_at_beginning = without_hashtag_number.gsub(/^no\s*\.\s*\d+/i, '')
    without_initials = without_no_at_beginning.gsub(/^(\w\.\s*)*/, '')
    without_ampersand = without_initials.gsub('&', 'and')
    without_non_english_letters = I18n.transliterate(without_ampersand)
    without_quotes_at_end = without_non_english_letters.gsub(/"([^"]*)"/, '')
    only_letters_and_numbers = without_quotes_at_end.gsub(/\W/, '')
    downcased = only_letters_and_numbers.downcase
    downcased.present? ? downcased : name
  end

  def self.for_collected_ink(collected_ink)
    new(collected_ink)
  end

  def initialize(collected_ink)
    @collected_ink = collected_ink
  end

  def run
    @collected_ink.simplified_brand_name = self.class.simplify(@collected_ink.brand_name)
    @collected_ink.simplified_line_name = self.class.simplify(@collected_ink.line_name)
    @collected_ink.simplified_ink_name = self.class.simplify(@collected_ink.ink_name)
  end
end
