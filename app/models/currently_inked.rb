class CurrentlyInked < ApplicationRecord

  belongs_to :collected_ink
  belongs_to :collected_pen
  belongs_to :user

  delegate :collected_inks_for_select, to: :user
  delegate :name, to: :collected_ink, prefix: 'ink', allow_nil: true
  delegate :name, to: :collected_pen, prefix: 'pen', allow_nil: true

  validate :collected_ink_belongs_to_user
  validate :collected_pen_belongs_to_user
  validate :pen_not_already_in_use
  validates :inked_on, presence: true

  after_initialize :set_default_inked_on

  def self.active
    where(archived_on: nil)
  end

  def self.archived
    where.not(archived_on: nil)
  end

  def name
    "#{collected_ink.name} - #{collected_pen.name}"
  end

  def collected_pens_for_select
    user.collected_pens_for_select(self)
  end

  private

  def set_default_inked_on
    self.inked_on ||= Date.today
  end

  def collected_ink_belongs_to_user
    return unless user_id && collected_ink
    errors.add(:collected_ink) if user_id != collected_ink.user_id
  end

  def collected_pen_belongs_to_user
    return unless user_id && collected_pen
    errors.add(:collected_pen) if user_id != collected_pen.user_id
  end

  def pen_not_already_in_use
    return unless user && collected_pen
    return if archived_on.present?
    errors.add(:collected_pen_id, "already in use") if user.currently_inkeds.active.where(collected_pen_id: collected_pen.id).where.not(id: id).exists?
  end

end
