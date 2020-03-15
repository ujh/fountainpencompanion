class Admins::MacroClustersController < Admins::BaseController

  def create
    cluster = MacroCluster.create!(cluster_params)
    render json: MacroClusterSerializer.new(cluster).serializable_hash.to_json
  end

  def update
    cluster = MacroCluster.find(params[:id])
    cluster.update!(cluster_params)
    render json: MacroClusterSerializer.new(cluster).serializable_hash.to_json
  end

  def destroy
    cluster = MacroCluster.find(params[:id])
    cluster.destroy!
    head :ok
  end

  private

  def cluster_params
    params.require(:data).require(:attributes).permit(
      :brand_name, :line_name, :ink_name, :color
    )
  end
end
