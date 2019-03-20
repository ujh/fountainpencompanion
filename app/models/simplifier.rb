class Simplifier

  def self.simplify(name, too_short: false)
    without_brackets = name.gsub(/\(.*\)/, '')
    without_no = without_brackets.gsub(/^no\s*\.\s*(\d+)/i, '\1')
    without_no = without_no.gsub(/^#?\d+/, '') unless too_short
    without_initials = remove_initials(without_no)
    without_ampersand = without_initials.gsub('&', 'and')
    without_non_english_letters = I18n.transliterate(without_ampersand)
    without_quotes_at_end = without_non_english_letters.gsub(/"([^"]*)"/, '')
    only_letters_and_numbers = without_quotes_at_end.gsub(/\W/, '')
    downcased = only_letters_and_numbers.downcase
    return name unless downcased.present?
    if !too_short && downcased.length < 5
      simplify(name, too_short: true)
    else
      downcased
    end
  end

  def self.remove_initials(name)
    return name if name =~ /^(\w\.\s*){3,}/
    name.gsub(/^(\w\.\s*)+/, '')
  end

  def self.brand(name)
    # return "24solar" if name =~ /^24\s+solar/i
    # return "ancientsong" if name =~ /^ancient\s+song/i
    # return "banmi" if name =~ /^ban\s*mi/i
    # return "kobe" if name =~ /^nagasawa/i
    # return "kyototag" if name =~ /(^tag\s+)|(\s+tag$)|(^tag$)/i
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
