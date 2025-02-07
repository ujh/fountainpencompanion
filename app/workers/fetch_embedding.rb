class FetchEmbedding
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker

  sidekiq_throttle concurrency: { limit: 1 }

  def perform(class_name, id)
    self.model = class_name.constantize.find_by(id: id)
    return unless model

    model.update!(embedding: fetch_embedding)
  end

  private

  attr_accessor :model

  def fetch_embedding
    Rails
      .cache
      .fetch("embedding:#{digest}") do
        response =
          client.embeddings(parameters: { model: "text-embedding-3-small", input: model.content })
        response.dig("data", 0, "embedding")
      end
  end

  def digest
    Digest::MD5.hexdigest(model.content)
  end

  def client
    OpenAI::Client.new(access_token:, log_errors: !Rails.env.production?)
  end

  def access_token
    if Rails.env.development?
      ENV.fetch("OPEN_AI_EMBEDDINGS", ENV.fetch("OPEN_AI_DEV_TOKEN", nil))
    else
      ENV.fetch("OPEN_AI_EMBEDDINGS")
    end
  end
end
