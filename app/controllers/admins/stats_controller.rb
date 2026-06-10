class Admins::StatsController < Admins::BaseController
  # Stat methods that take an Integer-coercible :arg.
  ARG_STATS = %w[pens_micro_clusters_prio_to_assign_count relevant_pens_micro_clusters_count].freeze

  # Stat methods callable with no argument: everything public on AdminStats
  # that isn't in ARG_STATS. Anything not in one of these two sets returns 404.
  NO_ARG_STATS = (AdminStats.instance_methods(false).map(&:to_s) - ARG_STATS).freeze

  def show
    return head :not_found unless stat_allowed?

    result = statistic
    return if performed?

    render json: result
  end

  private

  def stat_name
    params[:id].to_s
  end

  def stat_allowed?
    NO_ARG_STATS.include?(stat_name) || ARG_STATS.include?(stat_name)
  end

  def statistic
    if ARG_STATS.include?(stat_name) && params[:arg].present?
      AdminStats.new.public_send(stat_name, Integer(params[:arg]))
    else
      AdminStats.new.public_send(stat_name)
    end
  rescue ArgumentError, TypeError
    head :bad_request
  end
end
