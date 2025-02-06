class PenEmbedding < ApplicationRecord
  has_neighbors :embedding

  belongs_to :owner, polymorphic: true

  after_save :fetch_embedding

  private

  def fetch_embedding
    return unless content_previously_changed?

    FetchEmbedding.perform_async(self.class.name, id)
  end
end
