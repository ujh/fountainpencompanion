class AgentLog < ApplicationRecord
  belongs_to :owner, polymorphic: true

  scope :ink_clusterer, -> { where(name: "InkClusterer") }

  STATES = [
    PROCESSING = "processing",
    WAITING_FOR_APPROVAL = "waiting-for-approval",
    APPROVED = "approved",
    REJECTED = "rejected"
  ].freeze

  validates :state, inclusion: { in: STATES }

  scope :processing, -> { where(state: PROCESSING) }
  scope :waiting_for_approval, -> { where(state: WAITING_FOR_APPROVAL) }
  scope :approved, -> { where(state: APPROVED) }
  scope :rejected, -> { where(state: REJECTED) }
  scope :processed, -> { where(state: [APPROVED, REJECTED]) }

  def waiting_for_approval!
    update!(state: WAITING_FOR_APPROVAL)
  end

  def reject!
    update!(rejected_at: Time.current, state: REJECTED)
  end

  def approve!
    update!(approved_at: Time.current, state: APPROVED)
  end

  def processing?
    state == PROCESSING
  end
end
