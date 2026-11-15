# Number of users per pen brand and per pen model, used to rank autocomplete
# suggestions. Models are counted per brand and across all brands (with an
# empty brand_key). Refreshed periodically by RefreshAutocompletePopularities.
class PenNamePopularity < ApplicationRecord
  include MaterializedView

  FIELDS = %w[brand model].freeze

  MIN_POPULARITY = 2

  # Values of the given field ranked by AutocompleteRanking: the values of at
  # least MIN_POPULARITY users and the user's own values. If a brand is given,
  # only models of that brand are considered.
  def self.autocomplete_search(term, field, user:, brand: nil)
    field = field.to_s
    raise ArgumentError, "Unsupported field: #{field}" unless FIELDS.include?(field)

    popular = where(field: field, popularity: MIN_POPULARITY..).select("value AS name", :popularity)
    own = user.collected_pens
    if field == "model"
      brand_key = brand.to_s.strip.downcase
      popular = popular.where(brand_key: brand_key)
      own = own.where("lower(trim(collected_pens.brand)) = ?", brand_key) if brand_key.present?
    end
    own = own.autocomplete_candidates(field)

    AutocompleteRanking.new(merge_candidates(popular, own), term).names
  end

  # Values that only differ in case are shown once, with the more popular
  # spelling.
  def self.merge_candidates(popular, own)
    union = Arel::Nodes::UnionAll.new(popular.arel, own.arel)
    candidates = Arel::Nodes::As.new(union, Arel.sql("candidates"))
    from(candidates).group(Arel.sql("lower(candidates.name)")).select(
      "(array_agg(candidates.name ORDER BY candidates.popularity DESC))[1] AS name",
      "max(candidates.popularity) AS popularity"
    )
  end
  private_class_method :merge_candidates
end
