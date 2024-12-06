class Admins::StatsController < Admins::BaseController
  def show
    render json: statistic
  end

  private

  def statistic
    AdminStats.new.send(params[:id])
  end
end
