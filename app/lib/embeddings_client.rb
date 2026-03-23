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
        ctx = RubyLLM.context { |c| c.openai_api_key = access_token }
        response = ctx.embed(text, model: "text-embedding-3-small")
        response.vectors
      end
  end

  def digest
    Digest::MD5.hexdigest(text)
  end

  def access_token
    Rails.env.development? ? ENV.fetch("OPEN_AI_DEV_TOKEN", nil) : ENV.fetch("OPEN_AI_EMBEDDINGS")
  end
end
