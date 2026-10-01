# Filters and ranks autocomplete candidates for a search term.
#
# Candidates are given as a relation that selects (at least) a `name` and a
# `popularity` column. Matches are ranked by how well they match the term:
#
#   0. exact match (case-insensitive)
#   1. the name starts with the term
#   2. a word in the name starts with the term
#   3. the name contains the term (also ignoring punctuation and spaces)
#   4. the name is similar to the term (trigram similarity, catches typos)
#
# Within each tier, more popular names come first. Similar names are ordered
# by their similarity weighted with (the logarithm of) their popularity, so
# that a well known name beats a rare one that happens to be slightly closer.
class AutocompleteRanking
  LIMIT = 15
  # Trigram similarity is too noisy for very short terms
  FUZZY_MIN_LENGTH = 4
  SIMILARITY_THRESHOLD = 0.5
  NO_MATCH = 5

  attr_accessor :candidates, :term, :limit

  def initialize(candidates, term, limit: LIMIT)
    self.candidates = candidates
    self.term = term.to_s.strip.downcase
    self.limit = limit
  end

  def relation
    scored =
      model
        .unscoped
        .from(candidates, :candidates)
        .select("candidates.*", "#{tier_sql} AS tier", "#{similarity_sql} AS similarity")
    model
      .unscoped
      .from(scored, :scored)
      .select("scored.*")
      .where("scored.tier < ?", NO_MATCH)
      .order(
        Arel.sql(
          "scored.tier, " \
            "CASE WHEN scored.tier = 4 THEN scored.similarity * ln(scored.popularity + 1) END DESC, " \
            "scored.popularity DESC, scored.name"
        )
      )
      .limit(limit)
  end

  def names
    relation.map { |candidate| candidate[:name] }
  end

  private

  def model
    candidates.klass
  end

  def name_sql
    "lower(candidates.name)"
  end

  def tier_sql
    conditions = [
      ["#{name_sql} = ?", term],
      ["#{name_sql} LIKE ?", "#{like(term)}%"],
      ["#{words_sql} LIKE ?", "% #{like(words_term)}%"],
      [
        "(#{name_sql} LIKE ? OR #{compact_sql} LIKE ?)",
        "%#{like(term)}%",
        "%#{like(compact_term.presence || term)}%"
      ]
    ]
    conditions << ["word_similarity(?, candidates.name) >= ?", term, SIMILARITY_THRESHOLD] if fuzzy?
    whens =
      conditions.each_with_index.map do |condition, tier|
        "WHEN #{sanitize(condition)} THEN #{tier}"
      end
    "(CASE #{whens.join(" ")} ELSE #{NO_MATCH} END)"
  end

  def similarity_sql
    return "0" unless fuzzy?

    sanitize(["word_similarity(?, candidates.name)", term])
  end

  # The name with every run of non-alphanumeric characters replaced by a single
  # space and prefixed with a space, so that word starts can be matched with LIKE
  def words_sql
    "(' ' || regexp_replace(#{name_sql}, '[^[:alnum:]]+', ' ', 'g'))"
  end

  # The name without any non-alphanumeric characters, e.g. "kon-peki" => "konpeki"
  def compact_sql
    "regexp_replace(#{name_sql}, '[^[:alnum:]]+', '', 'g')"
  end

  def fuzzy?
    term.length >= FUZZY_MIN_LENGTH
  end

  def words_term
    term.gsub(/[^[:alnum:]]+/, " ").strip
  end

  def compact_term
    term.gsub(/[^[:alnum:]]+/, "")
  end

  def like(value)
    model.sanitize_sql_like(value)
  end

  def sanitize(condition)
    model.sanitize_sql_array(condition)
  end
end
