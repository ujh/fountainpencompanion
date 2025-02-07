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
    EmbeddingsClient.new.fetch(model.content)
  end
end
