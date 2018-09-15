class Simplifier

  def self.simplify(name)
    without_brackets = name.gsub(/\(.*\)/, '')
    without_numbers_at_beginning = remove_numbers_at_beginning(without_brackets)
    without_initials = remove_initials(without_numbers_at_beginning)
    without_ampersand = without_initials.gsub('&', 'and')
    without_non_english_letters = I18n.transliterate(without_ampersand)
    without_quotes_at_end = without_non_english_letters.gsub(/"([^"]*)"/, '')
    only_letters_and_numbers = without_quotes_at_end.gsub(/\W/, '')
    downcased = only_letters_and_numbers.downcase
    downcased.present? ? downcased : name
  end

  def self.remove_numbers_at_beginning(name)
    without_hashtag_number = name.gsub(/^#?\d+/, '')
    without_hashtag_number.gsub(/^no\s*\.\s*\d+/i, '')
  end

  def self.remove_initials(name)
    return name if name =~ /^(\w\.\s*){3,}/
    name.gsub(/^(\w\.\s*)+/, '')
  end

  def self.brand(name)
    return "24solar" if name =~ /^24\s+solar/i
    return "ancientsong" if name =~ /^ancient\s+song/i
    return "banmi" if name =~ /^ban\s*mi/i
    return "birminghampens" if name =~ /^birmingham/i
    return "lartisanpastellier" if name =~ /callifolio/i
    return "jherbin" if name =~ /jacques\s+herbin/i
    return "kobe" if name =~ /^nagasawa/i
    return "pilot" if name =~ /iroshizuku/i
    return "pilot" if name =~ /namiki/i
    return "kyototag" if name =~ /(^tag\s+)|(\s+tag$)|(^tag$)/i
    self.simplify(name)
  end

  def self.ink_name(name)
    self.simplify(name)
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
