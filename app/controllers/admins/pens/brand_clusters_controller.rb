class Admins::Pens::BrandClustersController < Admins::BaseController
  def index
    @brands = Pens::Brand.order(:name).includes(:models)
  end

  def new
    @brands = Pens::Brand.order(:name).includes(:models)
    @model = Pens::Model.unassigned.order(:brand).first
    redirect_to admins_dashboard_path if @model.blank?
  end

  def create
    model = Pens::Model.find(params[:model_id])
    brand = Pens::CreateBrandCluster.new(model).perform
    flash[:notice] = "Brand cluster '#{brand.name}' created"
    redirect_to new_admins_pens_brand_cluster_path
  end

  def update
    model = Pens::Model.find(params[:id])
    brand = Pens::Brand.find(params[:brand_id])
    Pens::UpdateBrandCluster.new(model, brand).perform
    redirect_to new_admins_pens_brand_cluster_path
  end
end
