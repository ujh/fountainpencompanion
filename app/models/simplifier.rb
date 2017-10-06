class Simplifier

  def self.simplify(name)
    I18n.transliterate(name.gsub(/\(.*\)/, ''))
  end

end
