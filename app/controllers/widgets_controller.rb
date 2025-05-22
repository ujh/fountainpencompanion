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

  def pen_and_ink_suggestion_data
    RequestPenAndInkSuggestion.new(
      user: current_user,
      suggestion_id: params[:suggestion_id].presence,
      ink_kind: params[:ink_kind].presence,
      extra_user_input: params[:extra_user_input].presence
    ).perform
  end
end
