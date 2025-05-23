class CheckInkClustering::Ignore < CheckInkClustering::Base
  def system_directive
    <<~TEXT
      You are reviewing the result of a clustering algorithm that clusters inks,
      creates new clusters, or ignores them. Here the algorithm suggested that the
      ink should be ignored.

      Inks should be ignored when:

      * It is a mix of inks
      * It is an unidentified ink
      * It is an ink that someone created themselves
      * It is an incomplete entry, e.g. a name that is not a full ink name on its own

      Ink mixes can be determined for example by:
      * The ink name contains two ink names that are separated by a non-word character
      * The ink name does not contain one of the known brand names
      * However, ink names can contain contain translations of the names separated by
        a non-word character, so be careful with that.

      You can search the web for the ink. When you do that keep the following in mind:
      * The results might not even contain the ink name. You need to double check that the ink name is actually present.
      * Fewer results make it more likely that the ink does not exist.
      * More results make it more likely that the ink does exist.

      You can search the internal database using the similarity search function.
      * The similarity is based on vector embeddings. The smaller the number the closer they are.
      * Many results with a small distance but none that really fit usually mean that the ink is not a full name.
    TEXT
  end

  function :approve_cluster_creation,
           "Approve ignoring of this ink",
           explanation_of_decision: {
             type: "string",
             description: "Explanation of why ignoring the ink was approved"
           } do |arguments|
    save_approval_and_stop!(arguments)
  end

  function :reject_cluster_creation,
           "Reject ignoring of this ink",
           explanation_of_decision: {
             type: "string",
             description: "Explanation of why ignoring the ink was rejected"
           } do |arguments|
    save_rejection_and_stop!(arguments)
  end
end
