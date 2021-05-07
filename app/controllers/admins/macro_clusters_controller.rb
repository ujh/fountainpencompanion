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
    index_query.select(<<~SQL)
      id,
      brand_name,
      line_name,
      ink_name,
      color,
      (
        SELECT COALESCE(array_to_json(array_agg(row_to_json(mi))), '[]')
        FROM (
          SELECT
            id,
            simplified_brand_name,
            simplified_line_name,
            simplified_ink_name,
            (
              SELECT COALESCE(array_to_json(array_agg(row_to_json(ci))), '[]')
              FROM (
                SELECT
                  MIN(id) AS id,
                  MIN(brand_name) AS brand_name,
                  MIN(line_name) AS line_name,
                  MIN(ink_name) AS ink_name,
                  MIN(maker) AS maker,
                  MIN(color) AS color
                FROM collected_inks
                WHERE collected_inks.micro_cluster_id = micro_clusters.id
                GROUP BY CONCAT(brand_name, line_name, ink_name)
              ) ci
            ) AS collected_inks
          FROM micro_clusters
          WHERE micro_clusters.macro_cluster_id = macro_clusters.id
        ) mi
      ) AS micro_clusters
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
