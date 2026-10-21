class CheckInkClustering::Ignore < CheckInkClustering::Base
  class ApproveClusterCreation < RubyLLM::Tool
    description "Approve ignoring of this ink"

    param :explanation_of_decision, desc: "Explanation of why ignoring the ink was approved"

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
    description "Reject ignoring of this ink"

    param :explanation_of_decision, desc: "Explanation of why ignoring the ink was rejected"

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
      ink should be ignored.

      Inks should be ignored when:

      * It is a mix of inks
      * It is an unidentified ink
      * It is an ink that someone created themselves
      * It is an incomplete entry, e.g. a name that is not a full ink name on its own
      * It references a product that is not an ink, e.g. a rollberball or ballpoint pen. Ink additives
        (shimmer, glitter and similar) are inks and are not ignored.

      Ink mixes can be determined for example by:
      * The ink name contains two ink names that are separated by a non-word character
      * The ink name does not contain one of the known brand names, but only when brand_catalogue_inks
        is below 3 and ink_users is below 3
      * However, ink names can contain contain translations of the names separated by
        a non-word character, so be careful with that.

      You can search the web for the ink. When you do that keep the following in mind:
      * The results might not even contain the ink name. You need to double check that the ink name is actually present.
      * Fewer results make it more likely that the ink does not exist, except when the evidence rule
        given with the ink data says that few or no results are not evidence that the ink does not exist.
      * More results make it more likely that the ink does exist.

      You can search the internal database using the similarity search function.
      * The similarity is based on vector embeddings. The smaller the number the closer they are.
      * Many results with a small distance but none that really fit usually mean that the ink is not a full name.
    TEXT
  end

  private

  def tools
    base_tools + [ApproveClusterCreation.new(agent_log), RejectClusterCreation.new(agent_log)]
  end
end
