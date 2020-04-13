class AssignMicroCluster
  include Sidekiq::Worker

  def perform(collected_ink_id)
    collected_ink = CollectedInk.find(collected_ink_id)
    cluster = MicroCluster.find_or_create_by!(
      simplified_brand_name: collected_ink.simplified_brand_name,
      simplified_line_name: collected_ink.simplified_line_name,
      simplified_ink_name: collected_ink.simplified_ink_name
    ) do |cluster|
      AdminMailer.new_cluster.deliver_later
    end
    collected_ink.update!(micro_cluster: cluster)
    UpdateMicroCluster.perform_async(cluster.id)
  end
end
