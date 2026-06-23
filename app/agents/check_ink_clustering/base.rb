class CheckInkClustering::Base
  include RubyLlmAgent

  MODEL_ID = "gpt-4.1"

  APPROVE = "approve"
  REJECT = "reject"

  class LogOfClustering < RubyLLM::Tool
    description "Log of the chat with the LLM that produced the action you are reviewing"

    attr_accessor :micro_cluster_agent_log

    def initialize(micro_cluster_agent_log)
      self.micro_cluster_agent_log = micro_cluster_agent_log
    end

    def execute
      micro_cluster_agent_log.transcript.to_json
    end
  end

  def initialize(agent_log_id)
    self.micro_cluster_agent_log = AgentLog.find_by(id: agent_log_id)
  end

  def perform
    return unless micro_cluster_agent_log

    if micro_cluster.collected_inks.present?
      prompt = [clustering_explanation, micro_cluster_data, extra_context].compact.join("\n\n")
      ask!(prompt)
      agent_log.waiting_for_approval!
      update_micro_cluster_agent_log!
      execute_decision!
    else
      reject_empty_micro_cluster!
    end
  end

  def agent_log = find_or_create_agent_log(micro_cluster_agent_log)

  private

  attr_accessor :micro_cluster_agent_log

  EMPTY_MICRO_CLUSTER_EXPLANATION =
    "The micro cluster has no inks in it. It is not possible to cluster an empty micro cluster."

  # The micro cluster lost its inks between clustering and review. Record the
  # reason on the child log, annotate the parent, then reject the parent log
  # outright so it never reaches a human reviewer.
  def reject_empty_micro_cluster!
    agent_log.update(
      extra_data: {
        "action" => "reject",
        "explanation_of_decision" => EMPTY_MICRO_CLUSTER_EXPLANATION
      }
    )
    agent_log.approve_by_agent!
    update_micro_cluster_agent_log!
    micro_cluster_agent_log.reject!
  end

  def base_tools
    [
      LogOfClustering.new(micro_cluster_agent_log),
      Tools::InkSimilaritySearchTool.new,
      Tools::InkFullTextSearchTool.new,
      Tools::InkWebSearchTool.new(agent_log)
    ]
  end

  def extra_context
    # Hook for subclasses to add additional context to the prompt
  end

  def clustering_explanation
    "Below is the reasoning of the AI for this action:
    #{micro_cluster_agent_log.extra_data["explanation_of_decision"]}"
  end

  def update_micro_cluster_agent_log!
    return unless agent_log.extra_data.present?

    micro_cluster_agent_log.update!(
      extra_data:
        micro_cluster_agent_log.extra_data.merge(
          follow_up_done: true,
          follow_up_action: agent_log.extra_data["action"],
          follow_up_action_explanation: agent_log.extra_data["explanation_of_decision"]
        )
    )
  end

  def execute_decision!
    if approved?
      InkClusterer.new(micro_cluster.id, agent_log_id: micro_cluster_agent_log.id).approve!(
        agent: true
      )
    elsif rejected?
      clusters_to_reprocess =
        InkClusterer.new(micro_cluster.id, agent_log_id: micro_cluster_agent_log.id).reject!(
          agent: true
        )
      clusters_to_reprocess.each do |cluster|
        RunInkClustererAgent.perform_async("InkClusterer", cluster.id)
      end
    end
  end

  def approved?
    agent_log.extra_data && agent_log.extra_data["action"] == APPROVE
  end

  def rejected?
    agent_log.extra_data && agent_log.extra_data["action"] == REJECT
  end

  def micro_cluster_data
    data = {
      names: micro_cluster.all_names,
      names_as_elements: micro_cluster.all_names_as_elements
    }
    data[:colors] = micro_cluster.colors if micro_cluster.colors.present?

    "This is the data for the ink to cluster: #{data.to_json}"
  end

  def micro_cluster
    @micro_cluster ||= micro_cluster_agent_log.owner
  end
end
