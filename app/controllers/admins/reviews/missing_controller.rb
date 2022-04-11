class Admins::Reviews::MissingController < Admins::BaseController
  def index
    @clusters = sorted_clusters
  end

  def show
    @cluster = MacroCluster.find(params[:id])
    @search_results = find_on_youtube(@cluster)
  end

  def add
    cluster = MacroCluster.find(params[:id])
    data = Unfurler::Youtube.new(params[:video_id]).perform
    CreateInkReviewSubmission.new(
      url: data.url,
      user: User.find_by(email: current_admin.email),
      macro_cluster: cluster,
      automatic: true,
    ).perform
    head :ok
  end

  private

  def find_on_youtube(cluster)
    search = client.list_searches('snippet', q: "#{cluster.name} ink", type: 'video')
    search.items.map do |item|
      video_id = item.id.video_id
      data = Unfurler::Youtube.new(video_id).perform
      [
        video_id,
        data
      ]
    end
  end

  def client
    Youtube::Client.new
  end

  def sorted_clusters
    MacroCluster.left_joins(
      :ink_reviews
    ).where(
      ink_reviews: {id: nil}
    ).joins(
      micro_clusters: :collected_inks
    ).includes(
      :brand_cluster
    ).where(
      collected_inks: { private: false }
    ).group("macro_clusters.id").select(
      "macro_clusters.*, count(macro_clusters.id) as ci_count"
    ).order("ci_count desc").page(params[:page]).per(10)
  end
end
