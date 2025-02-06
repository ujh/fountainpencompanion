class Youtube
  class Client
    APPLICATION_NAME = "Fountain Pen Companion"
    CREDENTIALS = YAML.load(ENV["GOOGLE_CREDENTIALS"])
    SECRETS = YAML.load(ENV["GOOGLE_CLIENT_SECRETS"])
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

    def initialize
      self.service = Google::Apis::YoutubeV3::YouTubeService.new
      self.service.client_options.application_name = APPLICATION_NAME
      self.service.authorization = authorize
    end

    def method_missing(method, *args, **kwargs)
      self.service.send(method, *args, **kwargs)
    end

    private

    attr_accessor :service

    def authorize
      client_id = Google::Auth::ClientId.from_hash(SECRETS)
      authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, Credentials.new)
      authorizer.get_credentials("default")
    end
  end
end
