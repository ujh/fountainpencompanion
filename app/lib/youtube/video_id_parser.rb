class Youtube
  module VideoIdParser
    module_function

    def parse(url)
      uri = URI(url)
      if uri.host =~ /youtube\.com/
        Rack::Utils.parse_query(uri.query)["v"] || shorts_id(uri.path)
      elsif uri.host =~ /youtu\.be/
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
