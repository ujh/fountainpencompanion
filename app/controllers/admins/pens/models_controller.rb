class Admins::Pens::ModelsController < Admins::BaseController
  def index
    respond_to do |format|
      format.json do
        clusters =
          Pens::Model
            .includes(model_micro_clusters: { model_variants: :micro_clusters })
            .ordered
            .page(params[:page])
        render json:
                 PensModelSerializer
                   .new(clusters, index_options(clusters))
                   .serializable_hash
                   .to_json
      end
      format.html do
        @clusters =
          Pens::Model.includes(:model_micro_clusters).search(params[:q]).ordered.page(params[:page])
      end
    end
  end

  def show
    cluster = Pens::Model.find(params[:id])
    render json: PensModelSerializer.new(cluster, show_options).serializable_hash.to_json
  end

  def create
    cluster = Pens::Model.create!(create_params)
    render json: PensModelSerializer.new(cluster, show_options).serializable_hash.to_json
  end

  def destroy
    cluster = Pens::Model.find(params[:id])
    cluster.destroy!
    redirect_to(request.referrer || admins_pens_models_path)
  end

  private

  def create_params
    (params["_jsonapi"] || params).dig(:data, :attributes).permit(:brand, :model)
  end

  def show_options
    {
      include: %i[model_micro_clusters model_micro_clusters.model_variants],
      fields: {
        model_variants: %i[brand model pens_model_micro_cluster],
        pens_model_micro_cluster: %i[model model_variants]
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
