class Admins::Descriptions::BrandsController < Admins::BaseController
  def index
    @brand_clusters =
      BrandCluster
        .where.not(description: "")
        .order(updated_at: :desc)
        .page(params[:page])
        .per(100)
  end
end
