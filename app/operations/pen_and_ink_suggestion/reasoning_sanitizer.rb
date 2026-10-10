module PenAndInkSuggestion::ReasoningSanitizer
  REPLACEMENTS = [
    [%r{<(script|style)\b.*?</\1\s*>}im, ""],
    [/<!--.*?-->/m, ""],
    [/!\[[^\]]*\]\([^)]*\)/, ""],
    [/!\[[^\]]*\]\[[^\]]*\]/, ""],
    [/\[([^\]]*)\]\([^)]*\)/, '\1'],
    [/\[([^\]]+)\]\[[^\]]*\]/, '\1'],
    [/^ {0,3}\[[^\]]+\]:.*$/, ""],
    [%r{</?[a-z][^>]*>}i, ""],
    [%r{\bhttps?://\S+|\bwww\.\S+}i, ""],
    [/^ {0,3}\#{1,6}[ \t]+/, ""],
    [/[ \t]*,?[ \t]*\bW[1-7](?:[ \t]*[-–][ \t]*W[1-7])?\b\+?/, ""],
    [/[ \t]*\([ \t]*\)/, ""],
    [/[ \t]+$/, ""],
    [/\n{3,}/, "\n\n"]
  ].freeze

  def self.call(text)
    REPLACEMENTS
      .reduce(text.to_s) { |result, (pattern, replacement)| result.gsub(pattern, replacement) }
      .strip
  end
end
