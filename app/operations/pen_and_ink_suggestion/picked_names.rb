class PenAndInkSuggestion::PickedNames
  attr_accessor :word_sets

  def initialize(*items)
    self.word_sets = items.compact.map { |item| words_of(item) }
  end

  def matches?(text)
    words = content_words(text)
    word_sets.any? { |set| covers?(set, words) }
  end

  private

  def words_of(item)
    fields =
      if item.is_a?(CollectedPen)
        [item.brand, item.model, item.color]
      else
        [item.brand_name, item.line_name, item.ink_name]
      end
    fields.flat_map { |field| PenAndInkSuggestion::NameText.words(field) }.to_set
  end

  def covers?(set, words)
    full, rest = words.partition { |word| set.include?(word) }
    full.any? && rest.all? { |word| initial?(word) && set.any? { |other| other.start_with?(word) } }
  end

  def initial?(word)
    word.length == 1 && word.match?(/[[:alpha:]]/) && vocabulary.evidence?(word)
  end

  def content_words(text)
    PenAndInkSuggestion::NameText
      .words(text)
      .reject do |word|
        vocabulary.filler?(word) || vocabulary.pen_word?(word) || vocabulary.ink_word?(word)
      end
  end

  def vocabulary = PenAndInkSuggestion::MentionVocabulary
end
