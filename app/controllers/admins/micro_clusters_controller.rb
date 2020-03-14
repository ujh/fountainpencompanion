class Admins::MicroClustersController < Admins::BaseController
  def index
    clusters = MicroCluster.includes(:collected_inks).order(
      :simplified_brand_name, :simplified_line_name, :simplified_ink_name
    ).page(params[:page])
    render json: MicroClusterSerializer.new(clusters, options(clusters)).serializable_hash.to_json
  end

  private

  def options(rel)
    {
      include: [ :collected_inks ],
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
