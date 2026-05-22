class Unfurler
  class Youtube
    class Captions
      MAX_CHARS = 8_000
      ENDPOINT = "https://www.youtube.com/api/timedtext".freeze

      # Try human-authored tracks first, then auto-generated (ASR). Most
      # ink-review channels rely on auto-captions; without ASR fallback the
      # coverage drops by an order of magnitude.
      ATTEMPTS = [
        { lang: "en" },
        { lang: "en-US" },
        { lang: "en", kind: "asr" },
        { lang: "en-US", kind: "asr" }
      ].freeze

      def initialize(video_id, connection: default_connection)
        self.video_id = video_id
        self.connection = connection
      end

      def fetch
        ATTEMPTS.each do |params|
          text = fetch_attempt(params)
          return text if text.present?
        end
        nil
      end

      private

      attr_accessor :video_id, :connection

      def fetch_attempt(params)
        response = connection.get(ENDPOINT, params.merge(v: video_id))
        return nil unless response.success?
        return nil if response.body.to_s.strip.empty?

        parse(response.body)
      rescue Faraday::Error
        nil
      end

      def parse(xml)
        doc = Nokogiri.XML(xml)
        text = doc.css("text").map { |node| CGI.unescapeHTML(node.text.to_s) }.join(" ")
        text = text.gsub(/\s+/, " ").strip
        return nil if text.empty?

        text.length > MAX_CHARS ? text[0, MAX_CHARS] : text
      end

      def default_connection
        Faraday.new(request: { open_timeout: 3, timeout: 8 }) { |c| c.response :follow_redirects }
      end
    end
  end
end
