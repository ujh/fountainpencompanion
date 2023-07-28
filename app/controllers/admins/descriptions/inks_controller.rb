class Admins::Descriptions::InksController < Admins::BaseController
  def index
    @ink_clusters =
      MacroCluster
        .where.not(description: "")
        .order(updated_at: :desc)
        .page(params[:page])
        .per(100)
  end
end
