class PenAndInkSuggestion::SuggestionMessage
  MARKDOWN_SPECIAL = /([\\`*_\[\]<>])/

  attr_accessor :pen, :ink, :nib_profile, :notes, :reasoning

  def initialize(pen:, ink:, nib_profile:, reasoning:, notes: [])
    self.pen = pen
    self.ink = ink
    self.nib_profile = nib_profile
    self.notes = notes
    self.reasoning = reasoning
  end

  def to_s
    [header, notes_block, reasoning].compact_blank.join("\n\n")
  end

  private

  def header
    "- **Pen:** #{escape(pen_name)}\n- **Ink:** #{escape(ink.name)}"
  end

  def pen_name
    label = nib_profile.label
    pen.nib.blank? && label ? "#{pen.name} · #{label}" : pen.name
  end

  def notes_block
    notes.map { |note| "_#{note}_" }.join("\n\n")
  end

  def escape(text)
    text.to_s.squish.gsub(MARKDOWN_SPECIAL) { "\\#{::Regexp.last_match(1)}" }
  end
end
