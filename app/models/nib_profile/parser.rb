class NibProfile
  class Parser
    JAPANESE_BRANDS =
      /(?<![a-z])(?:pilot|namiki|sailor|platinium|platinum|platnum|nakaya|taccia|nagasawa|bungu ?box|bungbox|wancher|kuretake|eboya|kakimori|sakura|ohashi|kyuseido)(?![a-z])/i
    PLATINUM_BRANDS = /platin(?:i)?um|platnum/i
    PILOT_BRANDS = /(?<![a-z])(?:pilot|namiki)(?![a-z])/i
    ESTERBROOK_BRANDS = /ester ?b?rook|esterbook/i
    LAMY_BRANDS = /(?<![a-z])lamy(?![a-z])/i
    BEGINNER_BRANDS = /(?<![a-z])(?:lamy|pelikan\w*)(?![a-z])/i
    GEL_BRANDS = /uni-?ball|(?<![a-z])(?:uni|pentel|zebra|muji|bic|paper ?mate)(?![a-z])/i

    JUNK_TOKEN =
      %r{[?\-.]+|none|unknown|unk|n/a|na|idk|tbd|various|multiple|multi|interchangeable|double ended|unmarked|standard|stock|default}
    JUNK = /\A(?:#{JUNK_TOKEN})(?: (?:#{JUNK_TOKEN}))*\z/
    NON_INKABLE =
      /ball ?point|\bbp\b|ball ?pen|boligrafo|bolígrafo|kugelschreiber|pencil|highlighter|marker|\bfelt\b|fineliner|\bgel\b|stylus/
    GEL_LINE = /\A\d*\.\d+ ?(?:mm)?\z/
    ROLLERBALL = /roller ?ball|\broller\b|\brb\b/
    DIP = /\bglass\b|\bdip\b|\bzebra g\b|\bnikko\b|crow ?quill/

    GOLD_KARAT = /\b(?:9|10|12|14|15|18|21|22) ?(?:k|kt|ct|karat|carat)\b|\b(?:585|750|875|916)\b/
    STEEL =
      /steel|\bsteal\b|\bss\b|stainless|edelstahl|\binox\w*|\bacier\b|iridium point|gold[ -]?(?:plated|tone|coated)/
    TITANIUM = /titan\w*|\bti\b|\bmonoc\b/
    GOLD = /\bgold\b|\bpalladium\b/

    PREFIXES = [
      [/\b(ef|f|m|b|bb)ci\b/, :italic],
      [/\bn-?(ef|f|mf|m|b)\b/, :naginata],
      [/\bh-?(ef|f|mf|m|b)\b/, nil],
      [/\bk(ef|f|m|b)\b/, nil],
      [/\bi(m|b)\b/, :italic],
      [/\bo(ef|f|m|b|bb|bbb|3b)\b/, :oblique],
      [/\bs(ef|f|fm|mf|m|b)\b/, :soft]
    ].freeze

    CHARACTERS = {
      stub: /stub|\bsu\b|\bjournaler\b/,
      italic: /italic|\bci\b|\bcsi\b|cursive|\bsig\b|\bkanji\b|calligraph|\bcm\b/,
      parallel: /\bparallel\b/,
      architect: /architect|\barch\b|\bscribe\b|\bhebrew\b|\barabic\b/,
      reverse_grind: /\breverse\b/,
      oblique: /oblique|left[ -]?foot|\brelief\b/,
      left_handed: /\blh\b|left[ -]?hand/,
      fude: /\bfude\b|\bbent\b|\bbrush\b/,
      naginata:
        /naginata|\bnag\b|\btogi\b|kodachi|long ?(?:knife|blade)|\bblade\b|\btecho\b|keiryu|\bcross (?:concord|point|music)\b|\bconcord\b|\bemperor\b|\bking (?:cobra|eagle)\b/,
      zoom: /\bzoom\b/,
      music: /\bmusic\b|\bms\b/,
      flex: /flex|\bfa\b|falcon|wet noodle|\bzebra g\b/,
      soft: /\bsoft\b|\belastic\b|semi[ -]?flex/,
      needlepoint: /needle ?point/,
      posting: /\bposting\b|\bpo\b/,
      waverly: /waverl?e?y\b|\bwa\b/,
      signature: /\bsignature\b/,
      beginner: /\bbeginner\b|anf[äa]nger/
    }.freeze
    SEMI_FLEX = /semi[ -]?flex\w*/

    GRADES = {
      "UEF" => /ultra[ -]?extra[ -]?fine|ultra[ -]?fine|\buef\b/,
      "EEF" => /extra[ -]?extra[ -]?fine|\beef\b|\bxxf\b/,
      "EF" => /extra[ -]?fin[aeo]|\bx ?f\b|\bef\b/,
      "MF" =>
        %r{\b(?:medium|med) ?[-/]? ?fine\b|\bfine ?[-/]? ?medium\b|\bmf\b|\bfm\b|\bf ?[-/] ?m\b|\bm ?[-/] ?f\b},
      "BBB" => /\bbbb\b|\b3b\b|triple[ -]?broad/,
      "BB" => /\bbb\b|double[ -]?broad|extra[ -]?broad|\beb\b|\bxb\b/,
      "C" => /\bcoarse\b|\bc\b/,
      "F" => /\bfine\b|\bfin[ao]\b|\bfein\b|\bf\b/,
      "M" => /\bmedium\b|\bmed\b|\bmedio\b|\bmedian[ao]\b|\bmittel\b|\bm\b/,
      "B" => /\bbroad\b|\bbold\b|\bbreit\b|\bancho\b|\bb\b/
    }.freeze

    PLATINUM_CODE = /(?<![\d.])(?:0\.)?0([235])(?![\d.])/
    PLATINUM_CODE_GRADES = { "2" => "EF", "3" => "F", "5" => "M" }.freeze
    PLATINUM_LINE_WIDTH_GRADES = { 0.2 => "EF", 0.3 => "F", 0.5 => "M" }.freeze
    ESTERBROOK_CODE = /\b[1-9](\d{3})\b/
    ESTERBROOK_STYLES = {
      "550" => ["EF", []],
      "556" => ["F", []],
      "668" => ["M", []],
      "128" => ["EF", %i[flex]],
      "314" => ["M", %i[oblique stub]],
      "048" => ["F", %i[stub]],
      "442" => ["M", %i[stub]]
    }.freeze

    LINE_WIDTH = /(?<![\d#.])(\d{1,2}(?:\.\d{1,2})?) ?(mm)?(?![\d.])/
    PARALLEL_WIDTHS = [1.5, 2.4, 3.8, 6.0].freeze
    STUB_WIDTH = 0.9
    CROSS_STROKE_RATIO = 0.35

    CODE_WIDTHS = [
      [/\bjournaler\b/, 0.57, 0.33],
      [/\bmini stub\b/, 0.7, nil],
      [/\bsu\b/, 0.63, nil],
      [/\bcm\b|calligraphy medium/, 0.6, nil],
      [/\bfa\b/, 0.35, nil],
      [/\bscribe\b/, 0.45, nil],
      [/\bkanji\b/, 0.6, nil]
    ].freeze
    LAMY_CURSIVE = /\bcursive\b/
    LAMY_CURSIVE_WIDTH = 0.6

    CHARACTER_WIDTHS = {
      parallel: 1.5,
      needlepoint: 0.22,
      posting: 0.22,
      signature: 1.0,
      music: 0.9,
      zoom: 0.8,
      fude: 0.9,
      naginata: 0.55,
      waverly: 0.5,
      left_handed: 0.6,
      beginner: 0.6,
      stub: 1.0,
      italic: 0.9,
      architect: 0.6,
      flex: 0.45
    }.freeze

    MODEL_TOKENS = /flex\w*|\bfude\b|\bparallel\b|\bmusic\b|\bzoom\b|\bstub\b|\d+\.\d+ ?mm\b/
    MODEL_TRAILING_GRADE = /\(\s*(uef|eef|xxf|ef|xf|f|mf|fm|m|b|bb|bbb)\s*\)\s*\z/i

    attr_accessor :nib, :brand, :model

    def initialize(nib, brand: nil, model: nil)
      self.nib = nib.to_s
      self.brand = brand.to_s
      self.model = model.to_s
    end

    def profile
      return parse(nib, source: :nib) if nib.strip.present?

      hint = model_hint
      return NibProfile.new(raw: nib, kind: :unknown) if hint.blank?

      parse(hint, source: :model)
    end

    private

    def parse(text, source:)
      text = clean(text)
      kind = kind_of(text)
      attributes = { raw: nib, kind:, source:, source_text: text }
      return NibProfile.new(**attributes) unless kind.in?(%i[fountain dip])

      text, prefix_characters = strip_prefixes(text)
      code_grade, code_characters = code_grade_in(text)
      mm = line_width_in(text)
      if (platinum_grade = platinum_line_width_grade(mm))
        code_grade = platinum_grade
        mm = nil
      end
      grade = grade_in(text) || code_grade
      characters = prefix_characters + characters_in(text) + code_characters
      characters = in_table_order(characters + line_width_characters(mm, characters))
      attributes.merge!(grade:, characters:, material: material_in(text))

      code_mm, cross_mm = code_width_in(text)
      nominal_mm = mm || code_mm || grade_width(grade) || character_width(characters)
      unless nominal_mm
        return NibProfile.new(**attributes, confidence: unsized_confidence(attributes))
      end

      width = NibProfile.width_class(nominal_mm)
      width_min, width_max = range(width, nominal_mm, cross_mm, characters)
      NibProfile.new(
        **attributes,
        width:,
        width_min:,
        width_max:,
        japanese_sizing: grade.present? && mm.nil? && code_mm.nil? && japanese_brand?,
        confidence: grade || mm || code_mm ? :high : :medium
      )
    end

    def clean(text)
      text
        .downcase
        .gsub(/(\d),(\d)/, '\1.\2')
        .gsub(/(?<![\d.])\.(\d)/, '0.\1')
        .gsub(/s\.i\.g\.?/, "sig")
        .gsub(/[<>()\[\]{},;:+|_]/, " ")
        .squish
    end

    def kind_of(text)
      return :unknown if text.blank? || JUNK.match?(text)
      return :non_inkable if NON_INKABLE.match?(text)
      return :non_inkable if GEL_BRANDS.match?(brand) && GEL_LINE.match?(text)
      return :rollerball if ROLLERBALL.match?(text)
      return :dip if DIP.match?(text)

      :fountain
    end

    def material_in(text)
      return :gold if GOLD_KARAT.match?(text)
      return :steel if STEEL.match?(text)
      return :titanium if TITANIUM.match?(text)

      :gold if GOLD.match?(text)
    end

    def strip_prefixes(text)
      characters = []
      PREFIXES.each do |pattern, character|
        text =
          text.gsub(pattern) do
            characters << character if character
            Regexp.last_match(1)
          end
      end
      [text, characters]
    end

    def characters_in(text)
      characters =
        CHARACTERS.select do |character, pattern|
          candidate = character == :flex ? text.gsub(SEMI_FLEX, "") : text
          pattern.match?(candidate)
        end
      characters = characters.keys
      characters << :signature if pilot_brand? && text.split.include?("s")
      characters << :zoom if japanese_brand? && text == "z"
      characters << :beginner if BEGINNER_BRANDS.match?(brand) && text == "a"
      characters
    end

    def grade_in(text)
      GRADES
        .find do |grade, pattern|
          next false if grade == "C" && !japanese_brand? && !text.include?("coarse")

          pattern.match?(text)
        end
        &.first
    end

    def code_grade_in(text)
      if (match = PLATINUM_CODE.match(text))
        return PLATINUM_CODE_GRADES[match[1]], []
      end

      match = ESTERBROOK_CODE.match(text)
      if match && (ESTERBROOK_BRANDS.match?(brand) || text.match?(/\A\d{4}\z/))
        return ESTERBROOK_STYLES.fetch(match[1], [nil, []])
      end

      [nil, []]
    end

    def line_width_in(text)
      text
        .scan(LINE_WIDTH)
        .each do |number, unit|
          next unless unit || number.include?(".")

          mm = number.to_f
          return mm if mm.between?(0.1, 7.0)
        end
      nil
    end

    def line_width_characters(mm, characters)
      return [] unless mm
      return [:parallel] if characters.include?(:parallel)
      return [:parallel] if pilot_brand? && PARALLEL_WIDTHS.include?(mm)
      return [] if mm < STUB_WIDTH || characters.intersect?(%i[italic architect fude music])

      [:stub]
    end

    def code_width_in(text)
      return LAMY_CURSIVE_WIDTH, nil if LAMY_BRANDS.match?(brand) && LAMY_CURSIVE.match?(text)

      CODE_WIDTHS.find { |pattern, _mm, _cross_mm| pattern.match?(text) }&.drop(1)
    end

    def grade_width(grade)
      return unless grade

      GRADE_WIDTHS.fetch(grade)[japanese_brand? ? :japanese : :western]
    end

    def platinum_line_width_grade(mm)
      PLATINUM_LINE_WIDTH_GRADES[mm] if PLATINUM_BRANDS.match?(brand)
    end

    def in_table_order(characters)
      CHARACTERS.keys.select { |character| characters.include?(character) }
    end

    def character_width(characters)
      CHARACTER_WIDTHS.find { |character, _mm| characters.include?(character) }&.last
    end

    def range(width, mm, cross_mm, characters)
      mins = [width]
      maxes = [width]
      if characters.intersect?(%i[stub italic])
        mins << NibProfile.width_class(cross_mm || mm * CROSS_STROKE_RATIO)
      end
      maxes << width + 2 if characters.include?(:architect)
      maxes << width + 3 if characters.include?(:flex)
      maxes << width + 1 if characters.include?(:soft)
      if characters.include?(:fude)
        mins << 3
        maxes << 7
      end
      if characters.include?(:naginata)
        mins << width - 1
        maxes << width + 2
      end
      if characters.intersect?(%i[zoom music])
        mins << width - 2
        maxes << width + 1
      end
      [mins.min.clamp(1, 7), maxes.max.clamp(1, 7)]
    end

    def unsized_confidence(attributes)
      return :material_only if attributes[:material]
      return :character_only if attributes[:characters].any?

      :none
    end

    def model_hint
      text = clean(model)
      tokens = text.gsub(SEMI_FLEX, "").scan(MODEL_TOKENS)
      trailing_grade = MODEL_TRAILING_GRADE.match(model)
      tokens << trailing_grade[1].downcase if trailing_grade
      tokens.join(" ")
    end

    def japanese_brand?
      JAPANESE_BRANDS.match?(brand)
    end

    def pilot_brand?
      PILOT_BRANDS.match?(brand)
    end
  end
end
