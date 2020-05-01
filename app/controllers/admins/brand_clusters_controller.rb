class Admins::BrandClustersController < Admins::BaseController

  def index
    @brand_clusters = BrandCluster.order(:name)
  end

  def new
    @brand_clusters = BrandCluster.order(:name)
    @macro_cluster = MacroCluster.unassigned.first
    redirect_to admins_dashboard_path if @macro_cluster.blank?
  end

  def create
    macro_cluster = MacroCluster.find(params[:macro_cluster_id])
    brand_cluster = BrandCluster.create!(name: macro_cluster.brand_name)
    macro_cluster.update!(brand_cluster: brand_cluster)
    flash[:notice] = "Brand cluster '#{brand_cluster.name}' created"
    redirect_to new_admins_brand_cluster_path
  end

  def update
    macro_cluster = MacroCluster.find(params[:id])
    brand_cluster = BrandCluster.find(params[:brand_cluster_id])
    macro_cluster.update!(brand_cluster: brand_cluster)
    brand_cluster.update_name!
    redirect_to new_admins_brand_cluster_path
  end
end
