class Admins::Pens::ModelVariantsController < Admins::BaseController
  def index
    respond_to do |format|
      format.json do
        clusters =
          Pens::ModelVariant
            .includes(micro_clusters: :collected_pens)
            .ordered
            .page(params[:page])
        render json:
                 PensModelVariantSerializer
                   .new(clusters, index_options(clusters))
                   .serializable_hash
                   .to_json
      end
    end
  end

  private

  def index_options(rel)
    {
      include: %i[micro_clusters micro_clusters.collected_pens],
      fields: {
        collected_pen: %i[
          brand
          model
          color
          material
          trim_color
          filling_system
          pens_micro_cluster
        ],
        pens_micro_cluster: [:model_variant]
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
