class InkEmbedding < ApplicationRecord
  has_neighbors :embedding

  belongs_to :owner, polymorphic: true
  belongs_to :macro_cluster, optional: true, class_name: "MacroCluster", foreign_key: :owner_id
  belongs_to :micro_cluster, optional: true, class_name: "MicroCluster", foreign_key: :owner_id
  belongs_to :collected_ink, optional: true, class_name: "CollectedInk", foreign_key: :owner_id

  after_save :fetch_embedding

  private

  def fetch_embedding
    return unless content_previously_changed?

    FetchEmbedding.perform_async(self.class.name, id)
  end
end
