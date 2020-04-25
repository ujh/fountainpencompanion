class AssignMicroCluster
  include Sidekiq::Worker

  def perform(collected_ink_id, macro_cluster_id = nil)
    collected_ink = CollectedInk.find(collected_ink_id)
    cluster = MicroCluster.find_or_create_by!(
      simplified_brand_name: collected_ink.simplified_brand_name,
      simplified_line_name: collected_ink.simplified_line_name,
      simplified_ink_name: collected_ink.simplified_ink_name
    ) do |cluster|
      # macro_cluster_id is set when we change the simplifier rules and need to
      # rerun the clustering
      if macro_cluster_id
        cluster.macro_cluster_id = macro_cluster_id
      else
        AdminMailer.new_cluster.deliver_later
      end
    end
    collected_ink.update!(micro_cluster: cluster)
    UpdateMicroCluster.perform_async(cluster.id)
  end
end
