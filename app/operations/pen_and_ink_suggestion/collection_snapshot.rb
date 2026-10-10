class PenAndInkSuggestion::CollectionSnapshot
  NON_INKABLE_KINDS = %i[non_inkable rollerball dip].freeze

  ItemStats =
    Data.define(:usage_count, :daily_usage_count, :last_activity_on, :last_used_on, :inked) do
      def inked? = inked
    end

  Pair = Data.define(:count, :last_inked_on)

  Inking =
    Data.define(
      :id,
      :collected_pen_id,
      :collected_ink_id,
      :inked_on,
      :archived_on,
      :created_at,
      :usage_count,
      :last_usage_on
    ) { def active? = archived_on.nil? }

  EMPTY_STATS =
    ItemStats.new(
      usage_count: 0,
      daily_usage_count: 0,
      last_activity_on: nil,
      last_used_on: nil,
      inked: false
    )

  attr_reader :today

  def initialize(user, as_of: nil)
    self.user = user
    self.as_of = as_of
    self.today = as_of ? as_of.to_date : Date.current
  end

  def inks
    @inks ||=
      as_of_view(
        scoped_items(user.collected_inks).includes(
          :tags,
          micro_cluster: {
            macro_cluster: :brand_cluster
          }
        )
      )
  end

  def pens
    @pens ||= as_of_view(scoped_items(user.collected_pens))
  end

  def fillable_inks
    @fillable_inks ||= inks.reject { |ink| ink.kind == "swab" }
  end

  def inkable_pens
    @inkable_pens ||= pens.reject { |pen| NON_INKABLE_KINDS.include?(nib_profile(pen).kind) }
  end

  def nib_profile(pen)
    nib_profiles[pen.id] ||= NibProfile.parse(pen.nib, brand: pen.brand, model: pen.model)
  end

  def tag_names(ink)
    Gutentag::TagNames.call(ink.tags.sort_by(&:id).map(&:name))
  end

  def stats_for(item)
    stats_by_item(item.class)[item.id] || EMPTY_STATS
  end

  def inked?(item)
    stats_for(item).inked?
  end

  def pair_history
    @pair_history ||=
      inkings_by_pair.transform_values do |pair_inkings|
        Pair.new(count: pair_inkings.size, last_inked_on: pair_inkings.map(&:inked_on).max)
      end
  end

  def active_inkings
    @active_inkings ||=
      as_of_view(
        user
          .currently_inkeds
          .where(id: inkings.select(&:active?).map(&:id))
          .includes(:collected_pen, :collected_ink)
          .order(:id)
      ).each do |currently_inked|
        as_of_view([currently_inked.collected_pen, currently_inked.collected_ink])
      end
  end

  def active_inking_for(pen)
    active_inkings
      .select { |inking| inking.collected_pen_id == pen.id }
      .max_by { |inking| [inking.inked_on, inking.id] }
  end

  def inking(id)
    inkings_by_id[id]
  end

  def inkings_since(date)
    inkings.select { |inking| inking.inked_on >= date }
  end

  def recent_inkings(items, limit: 3)
    pen_ids = items.grep(CollectedPen).map(&:id)
    ink_ids = items.grep(CollectedInk).map(&:id)
    return {} if pen_ids.empty? && ink_ids.empty?

    rows = as_of_view(ranked_inkings(pen_ids, ink_ids, limit).to_a)
    items.index_with do |item|
      column = item.is_a?(CollectedPen) ? :collected_pen_id : :collected_ink_id
      rows.select { |row| row[column] == item.id }.first(limit)
    end
  end

  private

  attr_accessor :user, :as_of
  attr_writer :today

  def scoped_items(relation)
    relation = relation.order(:id)
    return relation.active unless as_of

    relation
      .where(created_at: ..as_of)
      .where(archived_on: nil)
      .or(relation.where(created_at: ..as_of, archived_on: today.next_day..))
  end

  def as_of_view(records)
    records = records.to_a
    return records unless as_of

    records.each do |record|
      record.archived_on = nil if record.archived_on && record.archived_on > today
      record.readonly!
    end
  end

  def inkings
    @inkings ||=
      scoped_inkings(user.currently_inkeds)
        .joins(usage_join)
        .group(:id)
        .pluck(
          :id,
          :collected_pen_id,
          :collected_ink_id,
          :inked_on,
          :archived_on,
          :created_at,
          Arel.sql("COUNT(usage_records.id)"),
          Arel.sql("MAX(usage_records.used_on)")
        )
        .map { |values| build_inking(*values) }
  end

  def build_inking(id, pen_id, ink_id, inked_on, archived_on, created_at, usage_count, last_usage)
    Inking.new(
      id:,
      collected_pen_id: pen_id,
      collected_ink_id: ink_id,
      inked_on:,
      archived_on: archived_on && archived_on > today ? nil : archived_on,
      created_at:,
      usage_count:,
      last_usage_on: last_usage
    )
  end

  def scoped_inkings(relation)
    return relation unless as_of

    relation.where(inked_on: ..today, created_at: ..as_of)
  end

  def usage_join
    condition = "usage_records.currently_inked_id = currently_inked.id"
    if as_of
      condition +=
        ActiveRecord::Base.sanitize_sql(
          [" AND usage_records.used_on <= ? AND usage_records.created_at <= ?", today, as_of]
        )
    end
    "LEFT JOIN usage_records ON #{condition}"
  end

  def ranked_inkings(pen_ids, ink_ids, limit)
    ranked =
      scoped_inkings(
        user
          .currently_inkeds
          .where(collected_pen_id: pen_ids)
          .or(user.currently_inkeds.where(collected_ink_id: ink_ids))
      ).select(
        "currently_inked.*",
        "ROW_NUMBER() OVER (PARTITION BY collected_pen_id ORDER BY inked_on DESC, id DESC) AS pen_rank",
        "ROW_NUMBER() OVER (PARTITION BY collected_ink_id ORDER BY inked_on DESC, id DESC) AS ink_rank"
      )

    CurrentlyInked
      .from(ranked, :currently_inked)
      .where(
        "(collected_pen_id IN (?) AND pen_rank <= ?) OR (collected_ink_id IN (?) AND ink_rank <= ?)",
        pen_ids,
        limit,
        ink_ids,
        limit
      )
      .order(inked_on: :desc, id: :desc)
  end

  def nib_profiles
    @nib_profiles ||= {}
  end

  def inkings_by_id
    @inkings_by_id ||= inkings.index_by(&:id)
  end

  def stats_by_item(klass)
    @stats_by_item ||= {
      CollectedPen => item_stats(:collected_pen_id),
      CollectedInk => item_stats(:collected_ink_id)
    }
    @stats_by_item.fetch(klass)
  end

  def item_stats(column)
    inkings
      .group_by(&column)
      .transform_values do |item_inkings|
        inked = item_inkings.any?(&:active?)
        ItemStats.new(
          usage_count: item_inkings.size,
          daily_usage_count: item_inkings.sum(&:usage_count),
          last_activity_on: inked ? today : last_activity_on(item_inkings),
          last_used_on: legacy_item_last_used_on(item_inkings),
          inked:
        )
      end
  end

  def last_activity_on(item_inkings)
    item_inkings
      .flat_map { |inking| [inking.inked_on, inking.archived_on, inking.last_usage_on] }
      .compact
      .max
  end

  def legacy_item_last_used_on(item_inkings)
    newest = item_inkings.max_by { |inking| [inking.inked_on, inking.id] }
    legacy_last_used_on(newest) || newest.inked_on
  end

  def legacy_last_used_on(inking)
    inking.last_usage_on || previous_inking(inking)&.last_usage_on
  end

  def previous_inking(inking)
    inkings_by_pair[[inking.collected_pen_id, inking.collected_ink_id]]
      .reject { |other| other.id == inking.id }
      .max_by { |other| [other.created_at, other.id] }
  end

  def inkings_by_pair
    @inkings_by_pair ||=
      inkings.group_by { |inking| [inking.collected_pen_id, inking.collected_ink_id] }
  end
end
