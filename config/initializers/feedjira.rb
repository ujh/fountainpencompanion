Feedjira::Feed.add_common_feed_entry_element(
  :link,
  as: :alternate_url,
  value: :href,
  with: {
    rel: "alternate"
  }
)
