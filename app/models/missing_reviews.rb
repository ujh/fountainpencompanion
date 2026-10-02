# The public list of inks without reviews. Cached, as the page gets crawled a lot.
class MissingReviews
  EXPIRES_IN = 1.hour
  SORTED_IDS_KEY = "MissingReviews#sorted_ids"

  # Ids of the clusters without a review that have public collected inks,
  # sorted by name.
  def self.sorted_ids
    Rails
      .cache
      .fetch(SORTED_IDS_KEY, expires_in: EXPIRES_IN) do
        MacroCluster
          .without_review
          .where(
            id:
              MicroCluster
                .joins(:collected_inks)
                .where(collected_inks: { private: false })
                .select(:macro_cluster_id)
          )
          .order(:brand_name, :line_name, :ink_name)
          .pluck(:id)
      end
  end
end
