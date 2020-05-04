class Admins::MacroClustersController < Admins::BaseController

  def index
    respond_to do |format|
      format.json do
        clusters = index_query.includes(micro_clusters: :collected_inks)
        render json: MacroClusterSerializer.new(clusters, options(clusters)).serializable_hash.to_json
      end
      format.html do
        @clusters = index_query
      end
    end
  end

  def show
    cluster = MacroCluster.find(params[:id])
    render json: MacroClusterSerializer.new(
      cluster,
      include: [:micro_clusters, :'micro_clusters.collected_inks']
    ).serializable_hash.to_json
  end

  def create
    cluster = MacroCluster.create!(cluster_params)
    AssignMacroCluster.perform_async(cluster.id)
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

  def index_query
    MacroCluster.order(
      :brand_name, :line_name, :ink_name
    ).search(params[:q]).page(params[:page]).per(params[:per_page])
  end

  def cluster_params
    (params['_jsonapi'] || params).require(:data).require(:attributes).permit(
      :brand_name, :line_name, :ink_name, :color
    )
  end

  def options(rel)
    {
      include: [:micro_clusters, :'micro_clusters.collected_inks'],
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
