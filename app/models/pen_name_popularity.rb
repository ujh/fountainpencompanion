# Number of users per pen brand and per pen model (of a brand), used to rank
# autocomplete suggestions. Refreshed periodically by
# RefreshAutocompletePopularities.
class PenNamePopularity < ApplicationRecord
  include MaterializedView
end
