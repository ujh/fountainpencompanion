class AgentLog < ApplicationRecord
  belongs_to :owner, polymorphic: true

  scope :ink_clusterer, -> { where(name: "InkClusterer") }
  scope :unprocessed, -> { where(approved_at: nil, rejected_at: nil) }
  scope :processed, -> { where.not(approved_at: nil).or(where.not(rejected_at: nil)) }
  scope :approved, -> { where.not(approved_at: nil) }
  scope :rejected, -> { where.not(rejected_at: nil) }

  def reject!
    update(rejected_at: Time.current)
  end

  def approve!
    update(approved_at: Time.current)
  end
end
