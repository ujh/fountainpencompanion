class CurrentlyInked < ApplicationRecord

  include Archivable
  include PenName

  belongs_to :collected_ink
  belongs_to :collected_pen
  belongs_to :user

  delegate :collected_inks_for_select, to: :user
  delegate :collected_pens_for_select, to: :user
  delegate :name, to: :collected_ink, prefix: 'ink', allow_nil: true
  delegate :color, to: :collected_ink, prefix: 'ink'

  validate :collected_ink_belongs_to_user
  validate :collected_pen_belongs_to_user
  validate :pen_not_already_in_use
  validates :inked_on, presence: true

  after_initialize :set_default_inked_on
  before_save :update_nib

  def name
    "#{ink_name} - #{pen_name}"
  end

  def pen_name
    nib = if self.nib.present?
      self.nib
    else
      collected_pen.nib
    end
    pen_name_generator(
      brand: collected_pen.brand,
      model: collected_pen.model,
      nib: nib,
      color: collected_pen.color,
      archived: collected_pen.archived?
    )
  end

  def unarchivable?
    !user.currently_inkeds.where(collected_pen_id: collected_pen_id, archived_on: nil).exists?
  end

  def collected_pens_for_active_select
    ids = user.currently_inkeds.active.pluck(:collected_pen_id) - [collected_pen_id]
    user.collected_pens.active.where.not(id: ids)
  end

  def collected_inks_for_active_select
    user.active_collected_inks
  end

  private

  def set_default_inked_on
    self.inked_on ||= Date.today
  end

  def update_nib
    return unless archived_on_changed?
    if archived?
      self.nib = collected_pen.nib
    else
      self.nib = ""
    end
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
