class Youtube
  APPLICATION_NAME = 'Fountain Pen Companion'
  CREDENTIALS = YAML.load(ENV['GOOGLE_CREDENTIALS'])
  SECRETS = YAML.load(ENV['GOOGLE_CLIENT_SECRETS'])
  SCOPE = Google::Apis::YoutubeV3::AUTH_YOUTUBE_READONLY

  class Credentials
    def initialize
      @credentials = CREDENTIALS
    end

    def load(user_id)
      @credentials[user_id]
    end

    def store(user_id, json)
      @credentials[user_id] = json
    end
  end

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
    @client ||= begin
      service = Google::Apis::YoutubeV3::YouTubeService.new
      service.client_options.application_name = APPLICATION_NAME
      service.authorization = authorize
      service
    end
  end

  def authorize
    client_id = Google::Auth::ClientId.from_hash(SECRETS)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, Credentials.new)
    authorizer.get_credentials('default')
  end

end
