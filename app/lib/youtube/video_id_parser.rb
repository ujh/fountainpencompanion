class Youtube
  module VideoIdParser
    module_function

    def parse(url)
      uri = URI(url)
      host = uri.host.to_s.downcase
      if host == "youtube.com" || host.end_with?(".youtube.com")
        Rack::Utils.parse_query(uri.query)["v"] || shorts_id(uri.path)
      elsif host == "youtu.be" || host.end_with?(".youtu.be")
        uri.path[1..-1]
      end
    rescue URI::InvalidURIError
      nil
    end

    def shorts_id(path)
      match = path.match(%r{/shorts/([^/]+)})
      match && match[1]
    end
  end
end
