class PenAndInkSuggestion::SuggestionMessage
  MARKDOWN_SPECIAL = /([\\`*_\[\]<>])/
  SEPARATOR = "\n\n"

  attr_accessor :pen, :ink, :nib_profile, :notes, :reasoning

  def self.note_markdown(note)
    "_#{escape(note)}_"
  end

  def self.escape(text)
    text.to_s.squish.gsub(MARKDOWN_SPECIAL) { "\\#{::Regexp.last_match(1)}" }
  end

  def initialize(pen:, ink:, nib_profile:, reasoning:, notes: [])
    self.pen = pen
    self.ink = ink
    self.nib_profile = nib_profile
    self.notes = notes
    self.reasoning = reasoning
  end

  def to_s
    [header, notes_block, reasoning].compact_blank.join(SEPARATOR)
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
    notes.map { |note| self.class.note_markdown(note) }.join(SEPARATOR)
  end

  def escape(text)
    self.class.escape(text)
  end
end
