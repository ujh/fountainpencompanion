class PenAndInkSuggester
  class RecordSuggestion < RubyLLM::Tool
    description "Record the final suggestion: one pen and one ink, each by ref and name, and the " \
                  "reasoning."

    def name = "record_suggestion"

    param :pen_ref, desc: "Pen reference from the PENS list, e.g. P3"
    param :pen_name, desc: "Name of that pen as written in its PENS row"
    param :ink_ref, desc: "Ink reference from the INKS list, e.g. I12"
    param :ink_name, desc: "Name of that ink as written in its INKS row"
    param :reasoning, desc: "Markdown reasoning, 40-120 words, no headings, no list of the items"

    attr_accessor :selection, :rejected_pairs, :result, :violations

    def initialize(selection, rejected_pairs)
      self.selection = selection
      self.rejected_pairs = rejected_pairs
      self.violations = []
    end

    def execute(pen_ref:, ink_ref:, reasoning:, pen_name: nil, ink_name: nil)
      return halt("Suggestion already recorded") if result

      pen = selection.pen_for(pen_ref)
      return ref_error(pen_ref, "pen_ref", "a P ref from PENS") unless pen

      ink = selection.ink_for(ink_ref)
      return ref_error(ink_ref, "ink_ref", "an I ref from INKS") unless ink

      mismatch = name_mismatch(pen, ink, pen_name, ink_name)
      return mismatch if mismatch

      if rejected?(pen, ink)
        return "That exact pairing was rejected; choose a different pen or ink."
      end

      violation = selection.violation_for(pen:, ink:)
      if violation
        violations << violation
        return violation
      end
      return "Reasoning is blank." if reasoning.blank?

      self.result = { pen:, ink:, reasoning: }
      halt "Suggestion recorded"
    end

    private

    def name_mismatch(pen, ink, pen_name, ink_name)
      better_pen = selection.better_named_pen(pen, pen_name)
      better_ink = selection.better_named_ink(ink, ink_name)
      if better_pen
        mismatch_message(
          [selection.pen_ref(pen), selection.pen_display_name(pen)],
          ["pen_name", pen_name],
          selection.pen_ref(better_pen)
        )
      elsif better_ink
        mismatch_message(
          [selection.ink_ref(ink), ink.short_name],
          ["ink_name", ink_name],
          selection.ink_ref(better_ink)
        )
      end
    end

    def mismatch_message((ref, actual), (field, given), better_ref)
      "#{ref} is #{actual}, but #{field} says #{given.to_s.squish}, which fits #{better_ref} " \
        "better. Call record_suggestion again with the ref and name of the same row."
    end

    def ref_error(ref, field, expected)
      "#{ref.to_s.strip.presence || "A blank ref"} is not valid for #{field}; use #{expected}."
    end

    def rejected?(pen, ink)
      rejected_pairs.any? do |pair|
        pair = pair.to_h.stringify_keys
        pair["pen_id"] == pen.id && pair["ink_id"] == ink.id
      end
    end
  end
end
