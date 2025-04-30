class Admins::MicroClustersController < Admins::BaseController
  def index
    respond_to do |format|
      format.json do
        clusters =
          MicroCluster
            .includes(:collected_inks)
            .order(:simplified_brand_name, :simplified_line_name, :simplified_ink_name)
            .page(params[:page])
        clusters = clusters.unassigned if params[:unassigned]
        clusters = clusters.without_ignored if params[:without_ignored]
        render json:
                 MicroClusterSerializer
                   .new(clusters, index_options(clusters))
                   .serializable_hash
                   .to_json
      end
      format.html
    end
  end

  def ignored
    @clusters =
      MicroCluster
        .ignored
        .joins(:collected_inks)
        .select("micro_clusters.*, count(*) as count")
        .group("micro_clusters.id")
        .order("count desc, simplified_brand_name, simplified_line_name, simplified_ink_name")
  end

  def update
    cluster = MicroCluster.find(params[:id])
    cluster.update!(update_params)
    UpdateMicroCluster.perform_async(cluster.id)
    if cluster.previous_changes["ignored"] == [true, false]
      cluster.agent_logs.create!(
        name: "InkClusterer",
        state: AgentLog::APPROVED,
        transcript: [],
        extra_data: {
          action: "ignore_ink"
        }
      )
    end
    if request.referrer == ignored_admins_micro_clusters_url
      redirect_to ignored_admins_micro_clusters_url
    else
      render json: MicroClusterSerializer.new(cluster, update_options).serializable_hash.to_json
    end
  end

  def unassign
    cluster = MicroCluster.find(params[:id])
    macro_cluster_id = cluster.macro_cluster_id
    cluster.update!(macro_cluster_id: nil)
    UpdateMacroCluster.perform_async(macro_cluster_id)
    # Fake entry, to avoid generating the same outcome in the clustering agent again
    cluster.agent_logs.create!(
      name: "InkClusterer",
      state: AgentLog::APPROVED,
      transcript: [],
      extra_data: {
        action: "assign_to_cluster",
        cluster_id: cluster.id
      }
    )
    head :ok
  end

  private

  def update_params
    update_params = (params["_jsonapi"] || params).dig(:data, :attributes)
    update_params ||= params[:micro_cluster]
    update_params.permit(:macro_cluster_id, :ignored)
  end

  def index_options(rel)
    {
      include: [:collected_inks],
      fields: {
        collected_ink: %i[brand_name line_name ink_name maker color micro_cluster]
      },
      meta: {
        pagination: pagination(rel)
      }
    }
  end

  def update_options
    {
      include: %i[collected_inks macro_cluster],
      fields: {
        collected_ink: %i[brand_name line_name ink_name maker color micro_cluster]
      }
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
