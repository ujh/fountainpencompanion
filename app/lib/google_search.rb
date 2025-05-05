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

    filter_body(response.body)
  rescue StandardError => e
    "Search failed: #{e.message}"
  end

  private

  attr_accessor :query

  def filter_body(body)
    filtered_body = {}
    filtered_body["search_stats"] = body.dig("queries", "request", 0).slice(
      "totalResults",
      "searchTerms"
    )
    filtered_body["search_results"] = body["items"].map { |item| item.except("kind") }
    filtered_body
  end

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
