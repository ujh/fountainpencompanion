class CheckInkClustering::Base
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript
  include InkWebSearch
  include InkSimilaritySearch

  APPROVE = "approve"
  REJECT = "reject"

  def initialize(agent_log_id)
    self.micro_cluster_agent_log = AgentLog.find_by(id: agent_log_id)
    return unless micro_cluster_agent_log

    if agent_log.transcript.present?
      transcript.set!(agent_log.transcript)
    else
      transcript << { system: system_directive }
      transcript << { user: clustering_explanation }
      transcript << { user: micro_cluster_data }
      after_initialize
    end
  end

  def perform
    if micro_cluster.collected_inks.present?
      chat_completion(openai: "gpt-4.1")
    else
      agent_log.update(
        extra_data: {
          "action" => "reject",
          "explanation_of_decision" =>
            "The micro cluster has no inks in it. It is not possible to cluster an empty micro cluster."
        }
      )
    end
    agent_log.waiting_for_approval!
    if agent_log.extra_data.present?
      micro_cluster_agent_log.update!(
        extra_data:
          micro_cluster_agent_log.extra_data.merge(
            follow_up_done: true,
            follow_up_action: agent_log.extra_data["action"],
            follow_up_action_explanation: agent_log.extra_data["explanation_of_decision"]
          )
      )
    end
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
    else
      # Handed over to human. Nothing should happen here.
    end
  end

  def agent_log
    @agent_log ||= micro_cluster_agent_log.agent_logs.where(name: self.class.name).first
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

  def save_approval_and_stop!(arguments)
    agent_log.update(
      extra_data: {
        action: APPROVE,
        explanation_of_decision: arguments[:explanation_of_decision]
      }
    )
    stop_tool_calls_and_respond!
  end

  def save_rejection_and_stop!(arguments)
    agent_log.update(
      extra_data: {
        action: REJECT,
        explanation_of_decision: arguments[:explanation_of_decision]
      }
    )
    stop_tool_calls_and_respond!
  end
end
