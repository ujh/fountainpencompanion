require "csv"

class CurrentlyInked < ApplicationRecord
  include Archivable
  include PenName

  class NotRefillable < StandardError
  end

  paginates_per 100
  max_paginates_per 100

  belongs_to :collected_ink, counter_cache: true
  belongs_to :collected_pen
  belongs_to :user

  has_many :usage_records, dependent: :destroy
  has_one :last_usage, -> { order("used_on desc") }, class_name: "UsageRecord"

  delegate :collected_inks_for_select, to: :user
  delegate :collected_pens_for_select, to: :user
  delegate :name, :short_name, to: :collected_ink, prefix: "ink", allow_nil: true
  delegate :simplified_name, to: :collected_ink, prefix: "ink"
  delegate :color, to: :collected_ink, prefix: "ink"
  delegate :micro_cluster, to: :collected_ink, allow_nil: true
  delegate :macro_cluster, to: :micro_cluster, allow_nil: true

  validate :collected_ink_belongs_to_user
  validate :collected_pen_belongs_to_user
  validate :pen_not_already_in_use
  validates :inked_on, presence: true

  after_initialize :set_default_inked_on
  before_save :update_nib
  after_save :mark_ink_used

  def self.to_csv
    CSV.generate(col_sep: ";") do |csv|
      csv << ["Pen", "Ink", "Date Inked", "Date Cleaned", "Comment"]
      all.each { |ci| csv << [ci.pen_name, ci.ink_name, ci.inked_on, ci.archived_on, ci.comment] }
    end
  end

  def refill!
    raise NotRefillable unless refillable?
    archive!
    self.class.create!(
      collected_ink: collected_ink,
      collected_pen: collected_pen,
      inked_on: Date.current,
      user: user
    )
  end

  def daily_usage_count
    usage_records.size
  end

  def refillable?
    collected_ink.active? && collected_pen.active?
  end

  def used_today?
    last_used_on == Date.today
  end

  def last_used_on
    last_usage&.used_on || previous_record&.last_usage&.used_on
  end

  def name
    "#{ink_name} - #{pen_name}"
  end

  def pen_name
    nib = (self.nib.present? ? self.nib : collected_pen.nib)
    pen_name_generator(
      brand: collected_pen.brand,
      model: collected_pen.model,
      nib: nib,
      color: collected_pen.color,
      material: collected_pen.material,
      trim_color: collected_pen.trim_color,
      archived: collected_pen.archived?
    )
  end

  def unarchivable?
    ids ||= user.currently_inkeds.active.pluck(:collected_pen_id)
    !ids.include?(collected_pen_id) && collected_pen.active?
  end

  def collected_pens_for_active_select
    ids = user.currently_inkeds.active.pluck(:collected_pen_id) - [collected_pen_id]
    user.collected_pens.active.where.not(id: ids)
  end

  def collected_inks_for_active_select
    user.active_collected_inks.or(CollectedInk.where(id: collected_ink_id))
  end

  private

  def previous_record
    self
      .class
      .where(
        user_id: user_id,
        collected_ink_id: collected_ink_id,
        collected_pen_id: collected_pen_id
      )
      .where.not(id: id)
      .order("created_at desc")
      .first
  end

  def set_default_inked_on
    self.inked_on ||= Date.current
  end

  def update_nib
    return unless archived_on_changed?
    self.nib = (archived? ? collected_pen.nib : "")
  end

  def mark_ink_used
    collected_ink&.update(used: true)
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
    if user
         .currently_inkeds
         .active
         .where(collected_pen_id: collected_pen.id)
         .where.not(id: id)
         .exists?
      errors.add(:collected_pen_id, "already in use")
    end
  end
end
