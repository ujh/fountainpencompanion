class PenAndInkSuggestion::MentionMatcher
  Mention = Data.define(:text, :side)

  MAX_PHRASE = 8
  MAX_CODE_WORDS = 2
  NEGATION_WINDOW = 3
  BARE_MAX_ITEMS = 3
  BARE_MAX_WORDS = 4
  BRANDISH = %i[brand line].freeze
  CLAUSE_BREAK = /[.,;:!?()\[\]\n]/

  attr_accessor :index

  def self.call(index, instruction)
    new(index).call(instruction)
  end

  def initialize(index)
    self.index = index
  end

  def call(instruction)
    Scan.new(index, instruction.to_s).mentions
  end

  class Scan
    attr_accessor :index, :instruction, :tokens, :words

    def initialize(index, instruction)
      self.index = index
      self.instruction = instruction
      self.tokens = PenAndInkSuggestion::NameText.tokens(instruction)
      self.words = tokens.map(&:text)
    end

    def mentions
      found = []
      position = 0
      while position < words.size
        mention, position = mention_at(position)
        found << mention if mention
      end
      found.presence || [bare_mention].compact
    end

    private

    def vocabulary = PenAndInkSuggestion::MentionVocabulary

    def matches
      @matches ||= index.matches(words)
    end

    def mention_at(start)
      return nil, start + 1 if vocabulary.filler?(words[start])

      MAX_PHRASE.downto(1) do |length|
        positions = (start...(start + length)).to_a
        next unless phrase?(positions)

        pinning = matches.select { |match| pins_phrase?(match, positions) }
        return described_mention(positions, pinning) if pinning.any?
      end
      code_mention(start) || [nil, start + 1]
    end

    def phrase?(positions)
      positions.last < words.size && !vocabulary.filler?(words[positions.last]) &&
        positions.map { |position| clause(position) }.uniq.one?
    end

    def pins_phrase?(match, positions)
      fields = match.fields_at(positions)
      return false unless named_fields?(fields, positions)

      name_evidence =
        positions.zip(fields).count { |position, field| name_evidence?(position, field) }
      name_evidence >= 2 || (name_evidence == 1 && fields.intersect?(BRANDISH))
    end

    def named_fields?(fields, positions)
      positions
        .zip(fields)
        .all? do |position, field|
          (field && field != :extra) || vocabulary.filler?(words[position])
        end
    end

    def name_evidence?(position, field)
      field == :name && evidence?(position)
    end

    def evidence?(position)
      vocabulary.evidence?(words[position]) && !vocabulary.negation?(words[position])
    end

    def described_mention(positions, pinning)
      first = extend_left(positions.first, pinning)
      last = extend_right(positions.last, pinning)
      last = extend_over_code(first, last, pinning)
      return nil, last + 1 if negated?(first)

      sides = side_hint(last + 1)&.then { |hint| [hint] & pinning.map(&:side) }
      sides = pinning.map(&:side).uniq if sides.blank?
      [mention(first, last, sides), last + 1]
    end

    def extend_over_code(first, last, pinning)
      return last unless pinning.all? { |match| partial_name?(match, first..last) }

      codes = code_positions(last + 1)
      return last if codes.empty? || clause(codes.last) != clause(last)

      codes.last
    end

    def partial_name?(match, range)
      range.count { |position| match.covered[position] == :name } < match.entry.fields[:name].size
    end

    def extend_left(first, pinning)
      position = first - 1
      while position >= 0 && describes?(position, pinning)
        first = position unless vocabulary.filler?(words[position])
        position -= 1
      end
      first
    end

    def extend_right(last, pinning)
      position = last + 1
      while position < words.size && describes?(position, pinning)
        last = position unless vocabulary.filler?(words[position])
        position += 1
      end
      last
    end

    def describes?(position, pinning)
      return false if vocabulary.negation?(words[position])

      vocabulary.filler?(words[position]) || pinning.any? { |match| match.covered[position] }
    end

    def side_hint(position)
      position += 1 while position < words.size && vocabulary.filler?(words[position])
      word = words[position]
      if vocabulary.pen_word?(word)
        :pen
      elsif vocabulary.ink_word?(word)
        :ink
      end
    end

    def code_mention(start)
      brand_matches = matches.select { |match| match.covered[start] == :brand }
      return if brand_matches.empty?

      brand_start = start
      brand_start -= 1 while brand_start.positive? && brand_word?(brand_matches, brand_start - 1)
      brand_end = start
      brand_end += 1 while brand_word?(brand_matches, brand_end + 1)
      codes = code_positions(brand_end + 1)
      return if codes.empty? || clause(codes.last) != clause(start)
      return if brand_matches.any? { |match| codes.any? { |code| match.covered[code] == :name } }
      return nil, codes.last + 1 if negated?(brand_start)

      [mention(brand_start, codes.last, brand_matches.map(&:side).uniq), codes.last + 1]
    end

    def brand_word?(brand_matches, position)
      brand_matches.any? { |match| match.covered[position] == :brand }
    end

    def code_positions(from)
      codes = []
      position = from
      while position < words.size && codes.size < MAX_CODE_WORDS && code_word?(position)
        codes << position
        position += 1
      end
      codes.any? { |code| words[code].match?(/\d/) } ? codes : []
    end

    def code_word?(position)
      word = words[position]
      evidence?(position) && (word.match?(/\d/) || word.length <= 2)
    end

    def bare_mention
      return if words.size > BARE_MAX_WORDS

      content = words.each_index.select { |position| vocabulary.evidence?(words[position]) }
      if content.empty? || content.any? { |position| !evidence?(position) || negated?(position) }
        return
      end

      named =
        matches.select do |match|
          fields = match.fields_at(content)
          fields.all? { |field| field && field != :extra } && fields.include?(:name)
        end
      return if named.empty? || named.size > BARE_MAX_ITEMS

      mention(content.first, content.last, %i[pen ink])
    end

    def mention(first, last, sides)
      text = instruction[tokens[first].start...tokens[last].stop]
      Mention.new(text:, side: sides.one? ? sides.first : :any)
    end

    def negated?(position)
      ([position - NEGATION_WINDOW, 0].max...position).any? do |before|
        vocabulary.negation?(words[before]) && clause(before) == clause(position)
      end
    end

    def clause(position)
      clauses[position]
    end

    def clauses
      @clauses ||=
        tokens
          .each_with_index
          .each_with_object([]) do |(token, position), ids|
            ids << (position.zero? ? 0 : ids.last + (clause_break?(position) ? 1 : 0))
          end
    end

    def clause_break?(position)
      previous = tokens[position - 1]
      gap = instruction[previous.stop...tokens[position].start]
      gap = gap.delete_prefix(".") if initial?(previous)
      gap.match?(CLAUSE_BREAK)
    end

    def initial?(token)
      instruction[token.start...token.stop].match?(/\A[[:alpha:]]\z/)
    end
  end
end
