class PenEmbedding < ApplicationRecord
  has_neighbors :embedding

  belongs_to :owner, polymorphic: true
end
