class CheckInkClustering::Create < CheckInkClustering::Base
  class ApproveClusterCreation < RubyLLM::Tool
    description "Approve the creation of a new cluster"

    param :explanation_of_decision, desc: "Explanation of why the cluster creation was approved"

    attr_accessor :agent_log

    def initialize(agent_log)
      self.agent_log = agent_log
    end

    def execute(explanation_of_decision:)
      agent_log.update(
        extra_data: {
          action: CheckInkClustering::Base::APPROVE,
          explanation_of_decision: explanation_of_decision
        }
      )
      halt "approved"
    end
  end

  class RejectClusterCreation < RubyLLM::Tool
    description "Reject the creation of a new cluster"

    param :explanation_of_decision, desc: "Explanation of why the cluster creation was rejected"

    attr_accessor :agent_log

    def initialize(agent_log)
      self.agent_log = agent_log
    end

    def execute(explanation_of_decision:)
      agent_log.update(
        extra_data: {
          action: CheckInkClustering::Base::REJECT,
          explanation_of_decision: explanation_of_decision
        }
      )
      halt "rejected"
    end
  end

  def system_directive
    <<~TEXT
      You are reviewing the result of a clustering algorithm that clusters inks,
      creates new clusters, or ignores them. Here the algorithm suggested that the
      ink does not belong to any of the existing clusters and a new cluster should
      be created for it.

      New clusters should be created only when both apply:
      * No ink can be found that is similar enough to the ink
      * The rules for creating a new cluster given with the ink data are met. Run at least one web
        search for the ink before you approve. The evidence rule alone is never a reason to approve:
        when no web result names this ink, approve only under the specific product name exception of
        those rules and say so in your explanation.

      No new cluster should be created when:
      * The ink is a different spelling of the cluster
      * The ink is a translation of an existing cluster
      * There is evidence that the ink does not exist (see the evidence rule given with the ink data)
      * One of the reasons to ignore an ink given with the ink data applies, e.g. the ink is a mix of inks

      Ink mixes can be determined for example by:
      * The ink name contains two ink names that are separated by a non-word character
      * The ink name does not contain one of the known brand names, but only when brand_catalogue_inks
        is below 3 and ink_users is below 3
      * However, ink names can contain contain translations of the names separated by
        a non-word character, so be careful with that.

      You can search the web for the ink. When you do that keep the following in mind:
      * The results might not even contain the ink name. You need to double check that the ink name is actually present.

      You can search the internal database using the similarity search function.
      * The similarity is based on vector embeddings. The smaller the number the closer they are.
    TEXT
  end

  private

  def tools
    base_tools + [ApproveClusterCreation.new(agent_log), RejectClusterCreation.new(agent_log)]
  end
end
