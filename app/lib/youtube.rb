class Youtube

  def initialize(channel_id:)
    @channel_id = channel_id
  end

  def channel_name
    result = client.list_channels('snippet', id: @channel_id)
    result.items.first.snippet.title
  end

  def fetch_videos
    Enumerator.new do |yielder|
      result = client.list_playlist_items('snippet', playlist_id: uploads_id)
      loop do
        result.items.each do |item|
          yielder << transform_item(item)
        end
        next_page_token = result.next_page_token
        break unless next_page_token

        result = client.list_playlist_items('snippet', playlist_id: uploads_id, page_token: next_page_token)
      end
    end.lazy
  end

  private

  def transform_item(item)
    snippet = item.snippet
    video_id = snippet.resource_id.video_id
    {
      url: "https://youtube.com/watch?v=#{video_id}",
      title: snippet.title
    }
  end

  def uploads_id
    @uploads_id ||= begin
      result = client.list_channels('contentDetails', id: @channel_id)
      channel = result.items.first
      channel.content_details.related_playlists.uploads
    end
  end

  def client
    @client ||= Youtube::Client.new
  end
end