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
        response = client.embeddings(parameters: { model: "text-embedding-3-small", input: text })
        response.dig("data", 0, "embedding")
      end
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
