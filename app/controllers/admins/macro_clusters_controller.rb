class Admins::MacroClustersController < Admins::BaseController

  def index
    respond_to do |format|
      format.json do
        render plain: index_json
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

  def index_json
    meta = { pagination: pagination(index_query) }.to_json
    %Q({"data": #{index_json_from_pg}, "meta": #{meta} })
  end

  def index_json_from_pg
    sql = <<~SQL
      WITH macro_clusters AS (#{index_query_for_json_request.to_sql})
      SELECT row_to_json(macro_clusters.*) AS macro_cluster FROM macro_clusters
    SQL
    rows = ApplicationRecord.connection.execute(sql).values.flatten
    "[#{rows.join(",")}]"
  end

  def index_query_for_json_request
    index_query.left_joins(
      micro_clusters: :collected_inks
    ).group(
      'macro_clusters.id'
    ).select(<<~SQL)
      macro_clusters.id,
      macro_clusters.brand_name,
      macro_clusters.line_name,
      macro_clusters.ink_name,
      macro_clusters.color,
      (
        array_remove(
          array_agg(
            CASE WHEN collected_inks.id IS NOT NULL
            THEN jsonb_build_object(
              'id', collected_inks.id,
              'brand_name', collected_inks.brand_name,
              'line_name', collected_inks.line_name,
              'ink_name', collected_inks.ink_name,
              'maker', collected_inks.maker,
              'color', collected_inks.color
            )
            ELSE NULL END
          ),
          NULL
        )
      ) AS collected_inks
    SQL
  end

  def cluster_params
    (params['_jsonapi'] || params).require(:data).require(:attributes).permit(
      :brand_name, :line_name, :ink_name, :color
    )
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
