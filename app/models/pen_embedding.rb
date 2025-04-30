class PenEmbedding < ApplicationRecord
  has_neighbors :embedding

  belongs_to :owner, polymorphic: true
  belongs_to :pens_model, optional: true, class_name: "Pens::Model", foreign_key: :owner_id
  belongs_to :pens_model_variant,
             optional: true,
             class_name: "Pens::ModelVariant",
             foreign_key: :owner_id
  belongs_to :collected_pen, optional: true, class_name: "CollectedPen", foreign_key: :owner_id

  after_save :fetch_embedding

  private

  def fetch_embedding
    return unless content_previously_changed?

    FetchEmbedding.perform_async(self.class.name, id)
  end
end
