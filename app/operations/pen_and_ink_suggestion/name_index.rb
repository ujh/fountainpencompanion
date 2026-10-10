class PenAndInkSuggestion::NameIndex
  FIELD_PRIORITY = %i[brand line name extra].freeze
  MAX_RUN = 3

  class Entry
    attr_accessor :item, :side, :fields

    def initialize(item:, side:, fields:)
      self.item = item
      self.side = side
      self.fields = fields
    end
  end

  Match =
    Data.define(:entry, :covered) do
      def item = entry.item
      def side = entry.side

      def fields_at(positions)
        positions.map { |position| covered[position] }
      end
    end

  attr_accessor :entries

  def self.for(snapshot)
    new(pens: snapshot.pens, inks: snapshot.inks)
  end

  def initialize(pens:, inks:)
    self.entries = pens.map { |pen| pen_entry(pen) } + inks.map { |ink| ink_entry(ink) }
  end

  def matches(words, side: nil)
    hits = run_hits(words, side)
    candidates = hits.values.flat_map(&:keys).uniq
    candidates.map { |entry| Match.new(entry:, covered: coverage(entry, words, hits)) }
  end

  private

  def pen_entry(pen)
    Entry.new(
      item: pen,
      side: :pen,
      fields:
        {
          brand: pen.brand,
          name: pen.model,
          extra: [pen.color, pen.material, pen.trim_color, pen.nib].compact_blank.join(" ")
        }.transform_values { |text| PenAndInkSuggestion::NameText.words(text) }
    )
  end

  def ink_entry(ink)
    Entry.new(
      item: ink,
      side: :ink,
      fields:
        {
          brand: ink.brand_name,
          line: ink.line_name,
          name: ink.ink_name
        }.transform_values { |text| PenAndInkSuggestion::NameText.words(text) }
    )
  end

  def run_hits(words, side)
    hits = {}
    words.each_index do |start|
      1.upto(MAX_RUN) do |length|
        break if start + length > words.size

        form = words[start, length].join
        found = length == 1 ? word_lookup(form) : forms[form] || {}
        found = found.select { |entry, _field| entry.side == side } if side
        hits[[start, length]] = found if found.any?
      end
    end
    hits
  end

  def coverage(entry, words, hits)
    covered = Array.new(words.size)
    position = 0
    while position < words.size
      length = MAX_RUN.downto(1).find { |run| hits.dig([position, run], entry) }
      if length
        field = hits[[position, length]][entry]
        length.times { |offset| covered[position + offset] = field }
        position += length
      else
        position += 1
      end
    end
    covered
  end

  def word_lookup(word)
    word_lookups[word] ||= begin
      exact = forms[word] || {}
      if PenAndInkSuggestion::NameText.fuzzy?(word)
        fuzzy_words(word).reduce(exact) { |found, other| forms[other].merge(found) }
      else
        exact
      end
    end
  end

  def word_lookups
    @word_lookups ||= {}
  end

  def fuzzy_words(word)
    (word.length - 1..word.length + 1)
      .flat_map { |length| fuzzy_forms_by_length[length] || [] }
      .select { |other| other != word && PenAndInkSuggestion::NameText.same_word?(word, other) }
  end

  def fuzzy_forms_by_length
    @fuzzy_forms_by_length ||=
      forms.keys.select { |form| PenAndInkSuggestion::NameText.fuzzy?(form) }.group_by(&:length)
  end

  def forms
    @forms ||=
      entries.each_with_object({}) do |entry, index|
        FIELD_PRIORITY.reverse_each do |field|
          words = entry.fields[field] || []
          runs(words).each { |form| (index[form] ||= {})[entry] = field }
        end
      end
  end

  def runs(words)
    words.each_index.flat_map do |start|
      (1..MAX_RUN).filter_map { |length| words[start, length].join if start + length <= words.size }
    end
  end
end
