class Simplifier

  def self.simplify(name, too_short: false)
    without_brackets = name.gsub(/\(.*\)/, '')
    without_no = without_brackets.gsub(/^no\s*\.\s*(\d+)/i, '\1')
    return $1 if without_no =~ /^#?(\d+)$/
    without_no = without_no.gsub(/^#?\d+/, '') unless too_short
    without_initials = remove_initials(without_no)
    without_ampersand = without_initials.gsub('&', 'and')
    without_plus = without_ampersand.gsub('+', 'and')
    without_non_english_letters = I18n.transliterate(without_plus)
    without_quotes_at_end = without_non_english_letters.gsub(/"([^"]*)"/, '')
    only_letters_and_numbers = without_quotes_at_end.gsub(/\W/, '')
    without_year_at_end = only_letters_and_numbers.gsub(/\d\d\d\d$/, '')
    downcased = without_year_at_end.downcase
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

  def self.brand_name(name)
    return "24solar" if name =~ /^24\s+solar/i
    return "ancientsong" if name =~ /^(ancient\s*(charm|song))|(small\s*endowment)/i
    return "andersonpens" if name =~ /^anderson/i
    return "athena" if name =~ /^athena\s*ink$/i
    return "banmi" if name =~ /^ban\s*mi/i
    return "birminghampens" if name =~ /^birmingham/i
    return "bril" if name =~ /^bril/i
    return "herbin" if name =~/herbin/i
    return "kobe" if name =~ /^nagasawa/i
    return "kwz" if name =~ /^kwz/i
    return "kyototag" if name =~ /(^tag\s+)|(\s+tag$)|(^tag$)/i
    return "lamy" if name =~ /^lamy/i
    return "maruzen" if name =~ /^maruzen/i
    return "noodlers" if name =~ /^noodler/i
    return "pilot" if name =~ /iroshizuku/i
    return "robertoster" if name =~ /^robert\s*oster/i
    return "sbre" if name =~ /^sbre\s*(brown)?$/i
    return "thorntons" if name =~ /^thornton/i
    simplified = self.simplify(name)
    return "lecritoire" if simplified =~ /^lecritoire/
    return "organicsstudio" if simplified =~ /^organics?studios?$/
    return "pensalley" if simplified =~ /pensalley/
    simplified
  end

  def self.line_name(name)
    self.brand_name(name)
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
    @collected_ink.simplified_brand_name = self.class.brand_name(@collected_ink.brand_name)
    @collected_ink.simplified_line_name = self.class.line_name(@collected_ink.line_name)
    @collected_ink.simplified_ink_name = self.class.ink_name(@collected_ink.ink_name)
  end
end
