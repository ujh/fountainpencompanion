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
#
# The expensive checks (regular expressions, trigram similarity) are guarded
# by cheap LIKE conditions, as most candidates don't match at all. For similar
# names this assumes that either the first or the last two characters of the
# term are typed correctly.
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
    # OFFSET 0 keeps Postgres from pushing the tier filter down into the
    # candidates query. Otherwise aggregated names (e.g. array_agg(...)[1]) get
    # recomputed for every condition of the tier.
    scored =
      model
        .unscoped
        .from(candidates.offset(0), :candidates)
        .select("candidates.*", "#{tier_sql} AS tier")
    model
      .unscoped
      .from(scored, :scored)
      .select("scored.*")
      .where("scored.tier < ?", NO_MATCH)
      .order(
        Arel.sql(
          "scored.tier, " \
            "CASE WHEN scored.tier = 4 THEN #{similarity_sql("scored")} * ln(scored.popularity + 1) END DESC, " \
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
    whens = tier_conditions.map { |tier, condition| "WHEN #{sanitize(condition)} THEN #{tier}" }
    "(CASE #{whens.join(" ")} ELSE #{NO_MATCH} END)"
  end

  def tier_conditions
    conditions = [[0, ["#{name_sql} = ?", term]], [1, ["#{name_sql} LIKE ?", "#{like(term)}%"]]]
    conditions << [2, word_start_condition] if words.any?
    conditions << [3, ["#{name_sql} LIKE ?", "%#{like(term)}%"]]
    conditions << [3, compact_condition] if compact_term.present?
    conditions << [4, similarity_condition] if fuzzy?
    conditions
  end

  # A word in the name starts with the term. Words in the term can be separated
  # by any non-alphanumeric characters in the name, e.g. "kon peki" matches
  # "Kon-Peki". The words only contain alphanumeric characters, so they can be
  # used in LIKE patterns and regular expressions as they are.
  def word_start_condition
    [
      "#{name_sql} LIKE ? AND #{name_sql} ~ ?",
      "%#{words.join("%")}%",
      "(^|[^[:alnum:]])#{words.join("[^[:alnum:]]+")}"
    ]
  end

  # The name contains the term when ignoring punctuation and spaces, e.g.
  # "konpeki" matches "Kon-Peki"
  def compact_condition
    [
      "#{name_sql} LIKE ? AND regexp_replace(#{name_sql}, '[^[:alnum:]]+', '', 'g') LIKE ?",
      "%#{compact_term.chars.join("%")}%",
      "%#{compact_term}%"
    ]
  end

  def similarity_condition
    [
      "(#{name_sql} LIKE ? OR #{name_sql} LIKE ?) AND word_similarity(?, candidates.name) >= ?",
      "%#{like(term.first(2))}%",
      "%#{like(term.last(2))}%",
      term,
      SIMILARITY_THRESHOLD
    ]
  end

  def similarity_sql(table)
    sanitize(["word_similarity(?, #{table}.name)", term])
  end

  def fuzzy?
    term.length >= FUZZY_MIN_LENGTH
  end

  def words
    term.scan(/[[:alnum:]]+/)
  end

  def compact_term
    words.join
  end

  def like(value)
    model.sanitize_sql_like(value)
  end

  def sanitize(condition)
    model.sanitize_sql_array(condition)
  end
end
