class CheckInkClustering::Create < CheckInkClustering::Base
  SYSTEM_DIRECTIVE = <<~TEXT
    You are reviewing the result of a clustering algorithm that clusters inks,
    creates new clusters, or ignores them. Here the algorithm suggested that the
    ink does not belong to any of the existing clusters and a new cluster should
    be created for it.

    New clusters should be created when:
    * No ink can be found that is similar enough to the ink

    No new cluster should be created when:
    * The ink is a different spelling of the cluster
    * The ink is a translation of an existing cluster
    * The ink does not exist at all
    * The ink is a mix of inks

    Ink mixes can be determined for example by:
    * The ink name contains two ink names that are separated by a non-word character
    * The ink name does not contain one of the known brand names

    You can search the web for the ink. When you do that keep the following in mind:
    * The results might not even contain the ink name. You need to double check that the ink name is actually present.

    You can search the internal database using the similarity search function.
    * The similarity is based on vector embeddings. The smaller the number the closer they are.
  TEXT

  function :approve_cluster_creation,
           "Approve the creation of a new cluster",
           explanation_of_decision: {
             type: "string",
             description: "Explanation of why the cluster creation was approved"
           } do |arguments|
    save_approval_and_stop!(arguments)
  end

  function :reject_cluster_creation,
           "Reject the creation of a new cluster",
           explanation_of_decision: {
             type: "string",
             description: "Explanation of why the cluster creation was rejected"
           } do |arguments|
    save_rejection_and_stop!(arguments)
  end
end
