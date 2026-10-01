# Number of users per pen brand and per pen model, used to rank autocomplete
# suggestions. Models are counted per brand and across all brands (with an
# empty brand_key). Refreshed periodically by RefreshAutocompletePopularities.
class PenNamePopularity < ApplicationRecord
  include MaterializedView

  FIELDS = %w[brand model].freeze

  # Values of the given field ranked by AutocompleteRanking. If a brand is
  # given, only models of that brand are considered.
  def self.autocomplete_search(field, term, brand: nil)
    field = field.to_s
    raise ArgumentError, "Unsupported field: #{field}" unless FIELDS.include?(field)

    candidates = where(field: field)
    candidates = candidates.where(brand_key: brand.to_s.strip.downcase) if field == "model"
    AutocompleteRanking.new(candidates.select("value AS name", :popularity), term).names
  end
end
