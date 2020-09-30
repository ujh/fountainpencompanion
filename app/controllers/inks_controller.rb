class InksController < ApplicationController
  def index
    respond_to do |format|
      format.json {
        clusters = MacroCluster.autocomplete_ink_search(params[:term], params[:brand_name])
        serializer = MacroClusterSerializer.new(
          clusters, fields: { macro_cluster: [:ink_name]}
        )
        render json: serializer.serializable_hash.to_json
      }
      format.html {
        # These are ordered by rank!
        mc_ids = CollectedInk.search(params[:q]).where(private: false).joins(
          micro_cluster: :macro_cluster
        ).pluck('macro_clusters.id').uniq
        @clusters = MacroCluster.where(id: mc_ids).sort_by do |mc|
          mc_ids.index(mc.id)
        end
      }
    end
  end

  def show
    @ink = MacroCluster.find(params[:id])
    redirect_to brand_ink_path(@ink.brand_cluster, @ink) unless params[:brand_id]
  end
end
