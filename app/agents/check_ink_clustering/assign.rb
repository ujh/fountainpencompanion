class CheckInkClustering::Assign < CheckInkClustering::Base
  class ApproveAssignment < RubyLLM::Tool
    description "Approve the assignment of the ink to the cluster"

    param :explanation_of_decision, desc: "Explanation of why the assignment is correct"

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

  class RejectAssignment < RubyLLM::Tool
    description "Reject the assignment of the ink to the cluster"

    param :explanation_of_decision, desc: "Explanation of why the assignment is incorrect"

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
      creates new clusters or ignores them. Here the algorithm suggested that the
      ink should assigned to an existing cluster.

      You are tasked with checking if the assignment is correct. You are given
      the ink, the cluster it is assigned to, and the reasoning of the algorithm.

      Inks should be assigned to a cluster when:
      * The ink is a different spelling of the cluster
      * The ink is a translation of the cluster
      * Some parts of the name were added or removed, but it is still definitely the same ink

      Judge the name most users entered (the ink's main name), not a stray entry: an exact match or a
      clear spelling variant of the cluster's name is a correct assignment even when one entry carries
      an odd extra word, e.g. a suffix on the brand. Names that merely look similar are not enough: a
      similar-looking word is not a spelling variant. An unknown ink name that could combine or blend
      names of the maker's inks is a possible mix, not a typo. When in doubt between a typo and a
      different name, reject the assignment.

      An ink that is only a brand plus a colour name, with or without a line, follows the colour-only
      rule given with the ink data: assign it only to an ink of exactly that name or, when a line is
      given, to that line's only catalogue ink of that colour. Otherwise it should be ignored, not
      assigned to the brand's nearest named ink (Montblanc Green is not Montblanc Irish Green).

      When both the ink and the cluster have an RGB color, a similar color is a good
      indicator that the assignment is correct. However, it is not a requirement
      as the ink color sometimes gets set to an incorrect value by the user.

      You can search the web for the ink. When you do that keep the following in mind:
      * The results might not even contain the ink name. You need to double check that the ink name is actually present.

      You can search the internal database using the similarity search function.
      * The similarity is based on vector embeddings. The smaller the number the closer they are.
    TEXT
  end

  private

  def tools
    base_tools + [ApproveAssignment.new(agent_log), RejectAssignment.new(agent_log)]
  end

  def extra_context
    macro_cluster_data
  end

  def macro_cluster_data
    data = {
      names: macro_cluster.all_names.map(&:short_name),
      names_as_elements: macro_cluster.all_names_as_elements
    }
    "This is the data for the cluster to which the ink was assigned: #{data.to_json}"
  end

  def macro_cluster
    @macro_cluster ||= MacroCluster.find(micro_cluster_agent_log.extra_data["cluster_id"])
  end
end
