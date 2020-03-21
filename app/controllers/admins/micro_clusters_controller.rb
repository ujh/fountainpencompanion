class Admins::MicroClustersController < Admins::BaseController
  def index
    respond_to do |format|
      format.json {
        clusters = MicroCluster.includes(:collected_inks).order(
          :simplified_brand_name, :simplified_line_name, :simplified_ink_name
        ).page(params[:page])
        clusters = clusters.unassigned if params[:unassigned]
        render json: MicroClusterSerializer.new(clusters, options(clusters)).serializable_hash.to_json
      }
      format.html
    end
  end

  def update
    cluster = MicroCluster.find(params[:id])
    cluster.update!(update_params)
    render json: MicroClusterSerializer.new(cluster, include: [:collected_inks]).serializable_hash.to_json
  end

  private

  def update_params
    (params['_jsonapi'] || params).require(:data).require(:attributes).permit(:macro_cluster_id)
  end

  def options(rel)
    {
      include: [:collected_inks],
      meta: { pagination: pagination(rel) },
    }
  end

  def pagination(rel)
    {
      total_pages: rel.total_pages,
      current_page: rel.current_page,
      next_page: rel.next_page,
      prev_page: rel.prev_page
    }
  end
end
