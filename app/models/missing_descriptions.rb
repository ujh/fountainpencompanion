# The public lists of brands and inks without descriptions. Cached, as the page
# gets crawled a lot.
class MissingDescriptions
  EXPIRES_IN = 1.hour
  SORTED_BRAND_IDS_KEY = "MissingDescriptions#sorted_brand_ids"
  SORTED_INK_IDS_KEY = "MissingDescriptions#sorted_ink_ids"

  # Ids of the brand clusters without a description, sorted by name.
  def self.sorted_brand_ids
    Rails
      .cache
      .fetch(SORTED_BRAND_IDS_KEY, expires_in: EXPIRES_IN) do
        BrandCluster.without_description.order(:name).pluck(:id)
      end
  end

  # Ids of the clusters without a description that have public collected inks,
  # sorted by name.
  def self.sorted_ink_ids
    Rails
      .cache
      .fetch(SORTED_INK_IDS_KEY, expires_in: EXPIRES_IN) do
        MacroCluster.without_description.public.order(:brand_name, :line_name, :ink_name).pluck(:id)
      end
  end

  def self.expire_brands
    Rails.cache.delete(SORTED_BRAND_IDS_KEY)
  end

  def self.expire_inks
    Rails.cache.delete(SORTED_INK_IDS_KEY)
  end
end
