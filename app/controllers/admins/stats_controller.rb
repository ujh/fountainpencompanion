class Admins::StatsController < Admins::BaseController
  # Stat methods that take an Integer-coercible :arg.
  ARG_STATS = %w[pens_micro_clusters_prio_to_assign_count relevant_pens_micro_clusters_count].freeze

  # Stat methods callable with no argument: everything public on AdminStats
  # that isn't in ARG_STATS. Anything not in one of these two sets returns 404.
  NO_ARG_STATS = (AdminStats.instance_methods(false).map(&:to_s) - ARG_STATS).freeze

  # The dashboard polls every stat. Some of them are expensive counts over big
  # tables, so they are shared between requests for a short while.
  CACHE_DURATION = 1.minute

  def show
    return head :not_found unless stat_allowed?

    args = stat_args
    return head :bad_request if args.nil?

    render json: cached_statistic(args)
  end

  private

  def stat_name
    params[:id].to_s
  end

  def stat_allowed?
    NO_ARG_STATS.include?(stat_name) || ARG_STATS.include?(stat_name)
  end

  # Returns nil if the arg is not coercible to an Integer
  def stat_args
    return [] unless ARG_STATS.include?(stat_name) && params[:arg].present?

    [Integer(params[:arg])]
  rescue ArgumentError, TypeError
    nil
  end

  def cached_statistic(args)
    Rails
      .cache
      .fetch(["admin_stats", stat_name, *args], expires_in: CACHE_DURATION) do
        AdminStats.new.public_send(stat_name, *args)
      end
  end
end
