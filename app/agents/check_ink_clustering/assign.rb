class CheckInkClustering::Assign < CheckInkClustering::Base
  SYSTEM_DIRECTIVE = <<~TEXT
    You are reviewing the result of a clustering algorithm that clusters inks,
    creates new clusters or ignores them. Here the algorithm suggested that the
    ink should assigned to an existing cluster.

    You are tasked with checking if the assignment is correct. You are given
    the ink, the cluster it is assigned to, and the reasoning of the algorithm.

    Inks should be assigned to a cluster when:
    * The ink is a different spelling of the cluster
    * The ink is a translation of the cluster
    * Some parts of the name were added or removed, but it is still definitely the same ink

    When both the ink and the cluster have an RGB color, a similar color is a good
    indicator that the assignment is correct.

    You can search the web for the ink. When you do that keep the following in mind:
    * The results might not even contain the ink name. You need to double check that the ink name is actually present.

    You can search the internal database using the similarity search function.
    * The similarity is based on vector embeddings. The smaller the number the closer they are.
  TEXT

  private

  def after_initialize
    transcript << { user: macro_cluster_data }
  end

  def macro_cluster_data
    data = {
      names: macro_cluster.all_names.map(&:short_name),
      names_as_elements: macro_cluster.all_names_as_elements
    }
    "This is the data for the cluster to which the ink was assigned: #{data.to_json}"
  end

  function :approve_assignment,
           "Approve the assignment of the ink to the cluster",
           explanation_of_decision: {
             type: "string",
             description: "Explanation of why the assignment is correct"
           } do |arguments|
    save_approval_and_stop!(arguments)
  end

  function :reject_assignment,
           "Reject the assignment of the ink to the cluster",
           explanation_of_decision: {
             type: "string",
             description: "Explanation of why the assignment is incorrect"
           } do |arguments|
    save_rejection_and_stop!(arguments)
  end

  def macro_cluster
    @macro_cluster ||= MacroCluster.find(micro_cluster_agent_log.extra_data["cluster_id"])
  end
end
