# Number of public collected inks per macro cluster, used to rank autocomplete
# suggestions. Refreshed periodically by RefreshAutocompletePopularities.
class MacroClusterPopularity < ApplicationRecord
  include MaterializedView

  self.primary_key = :macro_cluster_id

  belongs_to :macro_cluster
end
