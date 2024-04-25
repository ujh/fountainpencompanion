class Admins::Pens::MicroClustersController < Admins::BaseController
  def index
    respond_to do |format|
      format.json do
        # FIXME: Adding an includes here breaks the serialization and does not include
        #        the collected pens anymore. This is due to the way the association is
        #        set up and not being really bi-directional.
        clusters =
          Pens::MicroCluster
            .includes(:collected_pens)
            .ordered
            .page(params[:page])
        clusters = clusters.unassigned if params[:unassigned]
        clusters = clusters.without_ignored if params[:without_ignored]
        render json:
                 PensMicroClusterSerializer
                   .new(clusters, index_options(clusters))
                   .serializable_hash
                   .to_json
      end
      format.html
    end
  end

  def ignored
    @clusters =
      Pens::MicroCluster
        .ignored
        .joins(:collected_pens)
        .select("pens_micro_clusters.*, count(*) as count")
        .group("pens_micro_clusters.id")
        .order(
          "count desc, simplified_brand, simplified_model, simplified_color, simplified_material, simplified_trim_color, simplified_filling_system"
        )
  end

  def update
    cluster = Pens::MicroCluster.find(params[:id])
    cluster.update!(update_params)
    Pens::UpdateMicroCluster.perform_async(cluster.id)
    render json:
             PensMicroClusterSerializer
               .new(cluster, update_options)
               .serializable_hash
               .to_json
  end

  private

  def update_params
    (params["_jsonapi"] || params).dig(:data, :attributes).permit(
      :ignored,
      :pens_model_variant_id
    )
  end

  def update_options
    {
      include: %i[collected_pens model_variant],
      fields: {
        collected_pen: %i[
          brand
          model
          color
          material
          trim_color
          filling_system
          pens_micro_cluster
        ]
      }
    }
  end

  def index_options(rel)
    {
      include: [:collected_pens],
      fields: {
        collected_pen: %i[
          brand
          model
          color
          material
          trim_color
          filling_system
          pens_micro_cluster
        ]
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
