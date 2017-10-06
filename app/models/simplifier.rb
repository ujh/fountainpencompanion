class Simplifier

  def self.simplify(name)
    without_brackets = name.gsub(/\(.*\)/, '')
    without_ampersand = without_brackets.gsub('&', 'and')
    I18n.transliterate(without_ampersand)
  end

end
