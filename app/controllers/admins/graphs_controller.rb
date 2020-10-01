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
    build User.active
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

  def build(base_relation)
    base_relation.where(
      'created_at > ?', 1.year.ago
    ).group("date_trunc('day', created_at)").order("day asc").pluck(
      "date_trunc('day', created_at) as day, count(*) as day_count"
    ).map do |d|
      [d.first.to_i*1000, d.last]
    end
  end
end
