class CheckInkClustering::Base
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript
  include InkWebSearch
  include InkSimilaritySearch

  def initialize(agent_log_id)
    self.micro_cluster_agent_log = AgentLog.find(agent_log_id)
    transcript << { system: SYSTEM_DIRECTIVE }
    transcript << { user: clustering_explanation }
    transcript << { user: micro_cluster_data }
    after_initialize
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4.1")
    agent_log.waiting_for_approval!
    micro_cluster_agent_log.update!(
      extra_data:
        micro_cluster_agent_log.extra_data.merge(
          follow_up_done: true,
          follow_up_action: agent_log.extra_data["action"],
          follow_up_action_explanation: agent_log.extra_data["explanation_of_decision"]
        )
    )
  end

  def agent_log
    @agent_log ||= micro_cluster_agent_log.agent_logs.create!(name: self.class.name, transcript: [])
  end

  function :log_of_clustering,
           "Log of the chat with the LLM that produced the action you are reviewing" do
    micro_cluster_agent_log.transcript.to_json
  end

  private

  attr_accessor :micro_cluster_agent_log

  def clustering_explanation
    "Below is the reasoning of the AI for this action:
    #{micro_cluster_agent_log.extra_data["explanation_of_decision"]}"
  end

  def after_initialize
    # Hook for the subclasses to perform any additional setup
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

  def save_approval_and_stop!(arguments)
    agent_log.update(
      extra_data: {
        action: "approve",
        explanation_of_decision: arguments[:explanation_of_decision]
      }
    )
    stop_looping!
  end

  def save_rejection_and_stop!(arguments)
    agent_log.update(
      extra_data: {
        action: "reject",
        explanation_of_decision: arguments[:explanation_of_decision]
      }
    )
    stop_looping!
  end
end
