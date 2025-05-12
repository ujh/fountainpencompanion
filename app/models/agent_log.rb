class AgentLog < ApplicationRecord
  belongs_to :owner, polymorphic: true, optional: true
  has_many :agent_logs, as: :owner, dependent: :destroy

  STATES = [
    PROCESSING = "processing",
    WAITING_FOR_APPROVAL = "waiting-for-approval",
    APPROVED = "approved",
    REJECTED = "rejected"
  ].freeze

  validates :state, inclusion: { in: STATES }

  scope :ink_clusterer, -> { where(name: "InkClusterer") }

  scope :processing, -> { where(state: PROCESSING) }
  scope :waiting_for_approval, -> { where(state: WAITING_FOR_APPROVAL) }
  scope :approved, -> { where(state: APPROVED) }
  scope :rejected, -> { where(state: REJECTED) }
  scope :processed, -> { where(state: [APPROVED, REJECTED]) }
  scope :manually_processed, -> { processed.where(agent_approved: false) }
  scope :agent_processed, -> { processed.where(agent_approved: true) }

  def waiting_for_approval!
    update!(state: WAITING_FOR_APPROVAL)
  end

  def reject!
    update!(rejected_at: Time.current, state: REJECTED, agent_approved: false)
  end

  def approve!
    update!(approved_at: Time.current, state: APPROVED, agent_approved: false)
  end

  def processing?
    state == PROCESSING
  end

  def approved?
    state == APPROVED
  end

  def action
    (extra_data || {})["action"]
  end
end
