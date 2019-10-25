class Admins::DashboardsController < Admins::BaseController

  def show
    @stats = AdminStats.new
  end
end
