module PenAndInkSuggestion::NameText
  Token = Data.define(:text, :start, :stop)

  FUZZY_LENGTH = 5

  module_function

  def tokens(text)
    text
      .to_s
      .to_enum(:scan, /[[:alnum:]]+/)
      .filter_map do
        match = Regexp.last_match
        normalized = normalize(match[0])
        if normalized.present?
          Token.new(text: normalized, start: match.begin(0), stop: match.end(0))
        end
      end
  end

  def words(text)
    tokens(text).map(&:text)
  end

  def normalize(word)
    word.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.gsub(/[^[:alnum:]]/, "")
  end

  def fuzzy?(word)
    word.length >= FUZZY_LENGTH && word.match?(/\A[[:alpha:]]+\z/)
  end

  def same_word?(left, right)
    left == right || (fuzzy?(left) && fuzzy?(right) && within_one_edit?(left, right))
  end

  def within_one_edit?(left, right)
    return false if (left.length - right.length).abs > 1

    short, long = [left, right].sort_by(&:length)
    index = 0
    index += 1 while index < short.length && short[index] == long[index]
    if short.length == long.length
      short[(index + 1)..] == long[(index + 1)..]
    else
      short[index..] == long[(index + 1)..]
    end
  end

  def distance(left, right)
    previous = (0..right.length).to_a
    left
      .each_char
      .with_index(1) do |left_char, row|
        current = [row]
        right
          .each_char
          .with_index(1) do |right_char, column|
            cost = left_char == right_char ? 0 : 1
            current << [
              previous[column] + 1,
              current[column - 1] + 1,
              previous[column - 1] + cost
            ].min
          end
        previous = current
      end
    previous.last
  end
end
