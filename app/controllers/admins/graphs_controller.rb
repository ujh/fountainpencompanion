class Admins::GraphsController < Admins::BaseController

  def show
    data = case params[:id]
           when 'signups' then signups
           when 'collected-inks' then collected_inks
           when 'collected-pens' then collected_pens
           when 'currently-inked' then currently_inked
           when 'usage-records' then usage_records
           end
    render json: data
  end

  private

  def signups
    [{
      data: build(User.active, range: 2.months),
      name: "Confirmed signups"
    }, {
      data: build(User.where(confirmed_at: nil, bot: false), range: 2.months),
      name: "Unconfirmed & not bot"
    }, {
      data: build(User.bots, range: 2.months),
      name: "Bot signups"
    }]
  end

  def collected_inks
    build CollectedInk
  end

  def collected_pens
    build CollectedPen
  end

  def currently_inked
    build CurrentlyInked
  end

  def usage_records
    build UsageRecord
  end

  def build(base_relation, range: 1.year)
    base_relation.where(
      'created_at > ?', range.ago
    ).group("date_trunc('day', created_at)").order("day asc").pluck(
      Arel.sql "date_trunc('day', created_at) as day, count(*) as day_count"
    ).map do |d|
      [d.first.to_i*1000, d.last]
    end
  end
end
