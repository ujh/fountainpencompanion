class WidgetsController < ApplicationController
  before_action :authenticate_user!

  def show
    case params[:id]
    when "inks_summary"
      render json: inks_summary_data
    when "pens_summary"
      render json: pens_summary_data
    when "currently_inked_summary"
      render json: currently_inked_summary_data
    when "leaderboard_ranking"
      render json: leaderboard_ranking_data
    when "inks_grouped_by_brand"
      render json: inks_grouped_by_brand_data
    when "pens_grouped_by_brand"
      render json: pens_grouped_by_brand_data
    when "pen_and_ink_suggestion"
      render json: pen_and_ink_suggestion_data
    when "usage_visualization"
      render json: usage_visualization_data
    else
      head :unprocessable_entity
    end
  end

  private

  def inks_summary_data
    active_inks = current_user.collected_inks.active
    as_json_api("inks_summary") do
      {
        count: active_inks.count,
        used: active_inks.where(used: true).count,
        swabbed: active_inks.where(swabbed: true).count,
        archived: current_user.collected_inks.archived.count,
        inks_without_reviews: my_unreviewed_inks.count,
        by_kind:
          active_inks
            .group(:kind)
            .select("kind, count(*) as count")
            .each_with_object({}) { |ink, acc| acc[ink.kind] = ink.count }
      }
    end
  end

  def my_unreviewed_inks
    MacroCluster.without_review_of_user(current_user)
  end

  def pens_summary_data
    as_json_api("pens_summary") do
      {
        count: current_user.collected_pens.active.count,
        archived: current_user.collected_pens.archived.count
      }
    end
  end

  def currently_inked_summary_data
    as_json_api("currently_inked_summary") do
      {
        active: current_user.currently_inkeds.active.count,
        total: current_user.currently_inkeds.count,
        usage_records: current_user.usage_records.count
      }
    end
  end

  def leaderboard_ranking_data
    as_json_api("leaderboard_ranking") do
      {
        inks: leaderboard_index(:inks),
        bottles: leaderboard_index(:bottles),
        samples: leaderboard_index(:samples),
        cartridges: leaderboard_index(:cartridges),
        brands: leaderboard_index(:brands),
        ink_review_submissions: leaderboard_index(:ink_review_submissions),
        description_edits: leaderboard_index(:users_by_description_edits)
      }
    end
  end

  def inks_grouped_by_brand_data
    brands =
      current_user
        .collected_inks
        .active
        .group(:brand_name)
        .select("brand_name, count(*) as count")
        .order("count desc")
    as_json_api("inks_grouped_by_brand") do
      { brands: brands.map { |ci| { brand_name: ci.brand_name, count: ci.count } } }
    end
  end

  def pens_grouped_by_brand_data
    brands =
      current_user
        .collected_pens
        .active
        .group(:brand)
        .select("brand, count(*) as count")
        .order("count desc")
    as_json_api("pens_grouped_by_brand") do
      { brands: brands.map { |ci| { brand_name: ci.brand, count: ci.count } } }
    end
  end

  def as_json_api(name)
    { data: { type: "widget", id: name, attributes: yield } }
  end

  def leaderboard_index(method)
    index = LeaderBoard.send(method).find_index { |entry| entry[:id] == current_user.id }
    index.succ if index
  end

  MAX_REJECTED_SUGGESTIONS = 50

  def pen_and_ink_suggestion_data
    RequestPenAndInkSuggestion.new(
      user: current_user,
      suggestion_id: params[:suggestion_id].presence,
      extra_user_input: params[:extra_user_input].presence,
      rejected_suggestions: parse_rejected_suggestions(params[:rejected_suggestions])
    ).perform
  end

  # The "rejected suggestions" list is built client-side from prior agent
  # outputs. Parse it as a strict JSON array of {ink_id, pen_id} integer
  # pairs and discard anything else, so attacker-supplied free-form text
  # can never reach the LLM prompt under this param.
  def parse_rejected_suggestions(raw)
    return [] if raw.blank?

    parsed = JSON.parse(raw)
    return [] unless parsed.is_a?(Array)

    parsed
      .first(MAX_REJECTED_SUGGESTIONS)
      .filter_map do |entry|
        next unless entry.is_a?(Hash)
        ink_id = safe_integer(entry["ink_id"])
        pen_id = safe_integer(entry["pen_id"])
        next unless ink_id && pen_id
        { "ink_id" => ink_id, "pen_id" => pen_id }
      end
  rescue JSON::ParserError
    []
  end

  def safe_integer(value)
    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end

  USAGE_VIZ_RANGES = {
    "1m" => 1.month,
    "3m" => 3.months,
    "6m" => 6.months,
    "1y" => 1.year,
    "all" => nil
  }.freeze

  COLOR_EXPRESSION = "COALESCE(NULLIF(collected_inks.color, ''), collected_inks.cluster_color)"

  def usage_visualization_data
    range = USAGE_VIZ_RANGES.key?(params[:range]) ? params[:range] : "1m"
    start_date = USAGE_VIZ_RANGES[range]&.ago&.to_date
    short_range = range == "1m"
    usage_threshold = short_range ? 10 : 20
    ci_threshold = short_range ? 5 : 10

    usage_scope = current_user.usage_records
    usage_scope = usage_scope.where("used_on >= ?", start_date) if start_date
    total_count = usage_scope.count

    if total_count > usage_threshold
      entries = usage_entries(usage_scope)
      source = "usage_records"
    else
      entries = currently_inked_entries
      source = "currently_inked"
      if entries.length <= ci_threshold
        entries = []
        source = "insufficient"
      end
    end

    as_json_api("usage_visualization") do
      { entries: entries, source: source, total_count: total_count }
    end
  end

  def usage_entries(scope)
    rows =
      scope
        .joins(currently_inked: :collected_ink)
        .left_joins(currently_inked: { collected_ink: :micro_cluster })
        .where("#{COLOR_EXPRESSION} IS NOT NULL")
        .group(
          "collected_inks.id",
          "collected_inks.brand_name",
          "collected_inks.ink_name",
          "micro_clusters.macro_cluster_id",
          COLOR_EXPRESSION
        )
        .order(Arel.sql("COUNT(*) DESC"))
        .pluck(
          "collected_inks.brand_name",
          "collected_inks.ink_name",
          Arel.sql(COLOR_EXPRESSION),
          Arel.sql("COUNT(*)"),
          "micro_clusters.macro_cluster_id"
        )
    build_entries(rows)
  end

  def currently_inked_entries
    rows =
      current_user
        .currently_inkeds
        .active
        .joins(:collected_ink)
        .left_joins(collected_ink: :micro_cluster)
        .where("#{COLOR_EXPRESSION} IS NOT NULL")
        .group(
          "collected_inks.id",
          "collected_inks.brand_name",
          "collected_inks.ink_name",
          "micro_clusters.macro_cluster_id",
          COLOR_EXPRESSION
        )
        .order(Arel.sql("COUNT(*) DESC"))
        .pluck(
          "collected_inks.brand_name",
          "collected_inks.ink_name",
          Arel.sql(COLOR_EXPRESSION),
          Arel.sql("COUNT(*)"),
          "micro_clusters.macro_cluster_id"
        )
    build_entries(rows)
  end

  def build_entries(rows)
    cluster_ids = rows.filter_map { |_, _, _, _, ink_id| ink_id }.uniq
    clusters = MacroCluster.where(id: cluster_ids).index_by(&:id)
    rows.map do |brand, ink, color, count, ink_id|
      cluster = clusters[ink_id]
      ink_name = cluster ? cluster.name : "#{brand} #{ink}"
      { ink_name: ink_name, color: color, count: count, ink_id: ink_id }
    end
  end
end
