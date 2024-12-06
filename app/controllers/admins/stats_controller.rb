class Admins::StatsController < Admins::BaseController
  def show
    render json: statistic
  end

  private

  def statistic
    args = [params[:id], params[:arg]].compact
    AdminStats.new.send(*args)
  end
end
