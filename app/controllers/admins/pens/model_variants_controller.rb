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
      format.html do
        @clusters =
          Pens::ModelVariant
            .includes(:micro_clusters)
            .ordered
            .page(params[:page])
      end
    end
  end

  def show
    cluster = Pens::ModelVariant.find(params[:id])
    render json:
             PensModelVariantSerializer
               .new(cluster, show_options)
               .serializable_hash
               .to_json
  end

  def create
    cluster = Pens::ModelVariant.create!(create_params)
    render json:
             PensModelVariantSerializer
               .new(cluster, show_options)
               .serializable_hash
               .to_json
  end

  def destroy
    cluster = Pens::ModelVariant.find(params[:id])
    cluster.destroy!
    redirect_to request.referrer
  end

  private

  def create_params
    (params["_jsonapi"] || params).dig(:data, :attributes).permit(
      :brand,
      :model,
      :color,
      :material,
      :trim_color,
      :filling_system
    )
  end

  def show_options
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
        pens_micro_cluster: %i[model_variant collected_pens]
      }
    }
  end

  def index_options(rel)
    show_options.merge(meta: { pagination: pagination(rel) })
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
