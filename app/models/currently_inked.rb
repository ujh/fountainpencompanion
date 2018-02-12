class CurrentlyInked < ApplicationRecord

  belongs_to :collected_ink
  belongs_to :collected_pen
  belongs_to :user

  delegate :name, to: :collected_ink, prefix: 'ink', allow_nil: true
  delegate :name, to: :collected_pen, prefix: 'pen', allow_nil: true

  validate :collected_ink_belongs_to_user
  validate :collected_pen_belongs_to_user

  private

  def collected_ink_belongs_to_user
    return unless user_id && collected_ink
    errors.add(:collected_ink) if user_id != collected_ink.user_id
  end

  def collected_pen_belongs_to_user
    return unless user_id && collected_pen
    errors.add(:collected_pen) if user_id != collected_pen.user_id
  end

end
