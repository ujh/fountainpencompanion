# Word diff of two HTML-escaped texts, rendered as HTML with <del class="differ"> and
# <ins class="differ">. Ports the greedy word algorithm of the differ gem (0.1.2) so existing
# history pages render the same, without its process-wide state.
class WordDiff
  MAX_TOKENS = 3_000
  TOO_LONG = '<em class="text-muted">Too long to compare.</em>'.freeze

  def initialize(new_text, old_text)
    self.target = tokens(new_text)
    self.source = tokens(old_text)
    self.parts = []
  end

  def html
    self.result ||= render
  end

  private

  attr_accessor :target, :source, :parts, :result

  def render
    return TOO_LONG if target.nil? || source.nil?

    advance until source.empty? || target.empty?
    target.empty? ? change(:delete, source) : change(:insert, target)
    parts.map { |part| part.is_a?(String) ? part : format_change(part) }.join
  end

  def tokens(text)
    text = text.to_s
    return text.split(/\b/) if text.length <= MAX_TOKENS

    split = text.split(/\b/)
    split if split.length <= MAX_TOKENS
  end

  def advance
    removed = source.shift
    added = target.shift
    prioritize_insert = target.length > source.length
    insert_at = target.index(removed)
    delete_at = source.index(added)

    if removed == added
      same(added)
    elsif insert_at && prioritize_insert
      take(:insert, target.unshift(added), insert_at)
    elsif delete_at
      take(:delete, source.unshift(removed), delete_at)
    elsif insert_at
      take(:insert, target.unshift(added), insert_at)
    else
      change(:insert, [added])
      change(:delete, [removed])
    end
  end

  def take(kind, tokens, index)
    change(kind, tokens.slice!(0..index))
    same(tokens.shift)
  end

  def same(token)
    parts.last.is_a?(String) ? parts.last << token : parts << token.dup
  end

  def change(kind, tokens)
    return if tokens.empty?

    parts << { delete: +"", insert: +"" } unless parts.last.is_a?(Hash)
    parts.last[kind] << tokens.join
  end

  def format_change(change)
    html = +""
    html << %(<del class="differ">#{change[:delete]}</del>) unless change[:delete].empty?
    html << %(<ins class="differ">#{change[:insert]}</ins>) unless change[:insert].empty?
    html
  end
end
