class AssignMicroCluster
  include Sidekiq::Worker

  def perform(collected_ink_id, macro_cluster_id = nil)
    self.collected_ink = CollectedInk.find(collected_ink_id)
    self.macro_cluster_id = macro_cluster_id
    find_or_create_cluster
    assign_macro_cluster_if_missing
    update_collected_ink
    update_embedding

    UpdateMicroCluster.perform_async(cluster.id)
  rescue ActiveRecord::RecordNotFound
    # do nothing
  end

  private

  attr_accessor :cluster, :collected_ink, :macro_cluster_id

  def find_or_create_cluster
    self.cluster =
      MicroCluster.find_or_create_by!(
        simplified_brand_name: collected_ink.simplified_brand_name,
        simplified_line_name: collected_ink.simplified_line_name,
        simplified_ink_name: collected_ink.simplified_ink_name
      ) do |cluster|
        micro_cluster =
          MicroCluster.find_by(
            simplified_brand_name: collected_ink.simplified_brand_name,
            simplified_ink_name: collected_ink.simplified_ink_name
          )
        cluster.macro_cluster_id = micro_cluster.macro_cluster_id if micro_cluster
      end
  end

  def assign_macro_cluster_if_missing
    return unless macro_cluster_id
    return if cluster.macro_cluster_id

    cluster.update!(macro_cluster_id: macro_cluster_id)
  end

  def update_collected_ink
    collected_ink.update!(micro_cluster: cluster)
  end

  def update_embedding
    embedding = cluster.ink_embedding || cluster.build_ink_embedding
    embedding.update(content: cluster.simplified_name)
  end
end
