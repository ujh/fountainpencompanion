class Youtube
  def initialize(channel_id:, client: Youtube::Client.new)
    self.channel_id = channel_id
    self.client = client
  end

  def channel_name
    result = client.list_channels("snippet", id: channel_id)
    result.items.first.snippet.title
  end

  def fetch_videos
    Enumerator
      .new do |yielder|
        result = client.list_playlist_items("snippet", playlist_id: uploads_id)
        loop do
          result.items.each { |item| yielder << transform_item(item) }
          next_page_token = result.next_page_token
          break unless next_page_token

          result =
            client.list_playlist_items(
              "snippet",
              playlist_id: uploads_id,
              page_token: next_page_token
            )
        end
      end
      .lazy
  end

  private

  attr_accessor :channel_id
  attr_accessor :client

  def transform_item(item)
    snippet = item.snippet
    video_id = snippet.resource_id.video_id
    { url: "https://youtube.com/watch?v=#{video_id}", title: snippet.title }
  end

  def uploads_id
    @uploads_id ||=
      begin
        result = client.list_channels("contentDetails", id: channel_id)
        channel = result.items.first
        channel.content_details.related_playlists.uploads
      end
  end
end
