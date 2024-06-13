class Admins::Pens::ModelMicroClustersController < Admins::BaseController
  def index
    respond_to do |format|
      format.json do
        clusters =
          Pens::ModelMicroCluster
            .includes(:model_variants)
            .ordered
            .page(params[:page])
        clusters = clusters.unassigned if params[:unassigned]
        clusters = clusters.without_ignored if params[:without_ignored]
        render json:
                 PensModelMicroClusterSerializer
                   .new(clusters, index_options(clusters))
                   .serializable_hash
                   .to_json
      end
      format.html
    end
  end

  def ignored
    @clusters =
      Pens::ModelMicroCluster
        .ignored
        .joins(:model_variants)
        .select("pens_model_micro_clusters.*, count(*) as count")
        .group("pens_model_micro_clusters.id")
        .order("count desc, simplified_brand, simplified_model")
  end

  def update
    cluster = Pens::ModelMicroCluster.find(params[:id])
    cluster.update!(update_params)
    Pens::UpdateModelMicroCluster.perform_async(cluster.id)
    render json:
             PensModelMicroClusterSerializer
               .new(cluster, update_options)
               .serializable_hash
               .to_json
  end

  def unassign
    cluster = Pens::ModelMicroCluster.find(params[:id])
    model_id = cluster.pens_model_id
    cluster.update!(pens_model_id: nil)
    Pens::UpdateModel.perform_async(model_id) if model_id.present?
    redirect_to(request.referrer || admins_pens_models_path)
  end

  private

  def update_params
    (params["_jsonapi"] || params).dig(:data, :attributes).permit(
      :ignored,
      :pens_model_id
    )
  end

  def update_options
    {
      include: %i[model_variants model],
      fields: {
        model_variant: %i[brand model pens_model_micro_cluster]
      }
    }
  end

  def index_options(rel)
    {
      include: [:model_variants],
      fields: {
        model_variant: %i[brand model pens_model_micro_cluster]
      },
      meta: {
        pagination: pagination(rel)
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
