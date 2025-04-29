class GoogleSearch
  def initialize(query)
    self.query = query
  end

  def perform
    response =
      connection.get("customsearch/v1") do |req|
        req.params["key"] = key
        req.params["cx"] = engine_id
        req.params["q"] = query
      end

    response.body
  rescue StandardError => e
    "Search failed: #{e.message}"
  end

  private

  attr_accessor :query

  def key
    ENV.fetch("GOOGLE_SEARCH_API_KEY")
  end

  def engine_id
    ENV.fetch("GOOGLE_SEARCH_ENGINE_ID")
  end

  def connection
    Faraday.new("https://www.googleapis.com/") do |c|
      c.request :url_encoded
      c.response :json
    end
  end
end
