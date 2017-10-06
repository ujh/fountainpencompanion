class Simplifier

  def self.simplify(name)
    without_brackets = name.gsub(/\(.*\)/, '')
    without_ampersand = without_brackets.gsub('&', 'and')
    without_non_english_letters = I18n.transliterate(without_ampersand)
    only_letters_and_numbers = without_non_english_letters.gsub(/\W/, '')
    downcased = only_letters_and_numbers.downcase
    downcased
  end

end
