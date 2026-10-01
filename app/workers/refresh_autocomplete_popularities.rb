class RefreshAutocompletePopularities
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  def perform
    MacroClusterPopularity.refresh
    PenNamePopularity.refresh
  end
end
