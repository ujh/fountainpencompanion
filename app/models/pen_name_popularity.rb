# Number of users per pen brand and per pen model (of a brand), used to rank
# autocomplete suggestions. Refreshed periodically by
# RefreshAutocompletePopularities.
class PenNamePopularity < ApplicationRecord
  include MaterializedView

  FIELDS = %w[brand model].freeze

  # Values of the given field ranked by AutocompleteRanking. If a brand is
  # given, only models of that brand are considered.
  def self.autocomplete_search(field, term, brand: nil)
    field = field.to_s
    raise ArgumentError, "Unsupported field: #{field}" unless FIELDS.include?(field)

    candidates = where(field: field)
    candidates = candidates.where(brand_key: brand.strip.downcase) if brand.present?
    if field == "model" && brand.blank?
      # Merge the same model name across brands
      candidates =
        candidates.group(:value_key).select(
          "(array_agg(value ORDER BY popularity DESC))[1] AS name",
          "sum(popularity) AS popularity"
        )
    else
      candidates = candidates.select("value AS name", :popularity)
    end
    AutocompleteRanking.new(candidates, term).names
  end
end
