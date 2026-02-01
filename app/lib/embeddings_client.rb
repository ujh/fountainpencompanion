class EmbeddingsClient
  def fetch(text)
    self.text = text
    fetch_embedding
  end

  private

  attr_accessor :text

  def fetch_embedding
    Rails
      .cache
      .fetch("embedding:#{digest}", expires_in: 1.week) do
        if ENV["USE_OLLAMA"] == "true"
          fetch_ollama_embedding
        else
          response = client.embeddings(parameters: { model: "text-embedding-3-small", input: text })
          response.dig("data", 0, "embedding")
        end
      end
  end

  def fetch_ollama_embedding
    # Ollama uses a different API format: POST /api/embeddings
    response =
      Faraday.post("http://ollama:11434/api/embeddings") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = { model: "nomic-embed-text", prompt: text }.to_json
      end

    embedding = JSON.parse(response.body)["embedding"]
    # Pad nomic-embed-text's 768 dimensions to 1536 with zeros for database compatibility
    pad_embedding(embedding)
  end

  def pad_embedding(embedding)
    # nomic-embed-text produces 768-dimensional vectors
    # OpenAI's text-embedding-3-small produces 1536-dimensional vectors
    # Pad with zeros to maintain database schema compatibility
    embedding + Array.new(1536 - embedding.length, 0.0)
  end

  def digest
    Digest::MD5.hexdigest(text)
  end

  def client
    @client ||= OpenAI::Client.new(access_token:, log_errors: !Rails.env.production?)
  end

  def access_token
    Rails.env.development? ? ENV.fetch("OPEN_AI_DEV_TOKEN", nil) : ENV.fetch("OPEN_AI_EMBEDDINGS")
  end
end
