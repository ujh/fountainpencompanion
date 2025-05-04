class InkClustererCheckAssignment
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript

  SYSTEM_DIRECTIVE = <<~TEXT
    You are tasked with reviewing the assignment of an ink to a cluster done by
    an AI algorithm. You can either approve the assignment or reject it. The
    clustering AI can have made mistakes, so you should double check the assignment
    is correct. Below are the details of the clustering AI's decision, the ink
    data as well as the cluster data. You can also review the chat log of the
    clustering AI that led to the assignment.
  TEXT

  def initialize(agent_log_id)
    self.micro_cluster_agent_log = AgentLog.find(agent_log_id)
    transcript << { system: SYSTEM_DIRECTIVE }
    transcript << { user: clustering_explanation }
    transcript << { user: micro_cluster_data }
    transcript << { user: macro_cluster_data }
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4.1")
    agent_log.waiting_for_approval!
    micro_cluster_agent_log.update!(
      extra_data:
        micro_cluster_agent_log.extra_data.merge(
          follow_up_done: true,
          follow_up_action: agent_log.extra_data["action"]
        )
    )
  end

  def agent_log
    @agent_log ||= micro_cluster_agent_log.agent_logs.create!(name: self.class.name, transcript: [])
  end

  private

  attr_accessor :micro_cluster_agent_log

  def clustering_explanation
    "Below is the reasoning of the AI for the clustering:
    #{micro_cluster_agent_log.extra_data["explanation_of_decision"]}"
  end

  def micro_cluster_data
    data = {
      names: micro_cluster.all_names,
      names_as_elements: micro_cluster.all_names_as_elements
    }
    data[:colors] = micro_cluster.colors if micro_cluster.colors.present?

    "This is the data for the ink to cluster: #{data.to_json}"
  end

  def macro_cluster_data
    data = {
      names: macro_cluster.all_names.map(&:short_name),
      names_as_elements: macro_cluster.all_names_as_elements
    }
    "This is the data for the cluster to which the ink was assigned: #{data.to_json}"
  end

  function :approve_assignment, "Approve the assignment of the ink to the cluster" do
    agent_log.update(extra_data: { action: "approve_assignment" })
    stop_looping!
  end

  function :reject_assignment, "Reject the assignment of the ink to the cluster" do
    agent_log.update(extra_data: { action: "reject_assignment" })
    stop_looping!
  end

  function :log_of_clustering,
           "Log of the chat with the LLM that produced the cluster assignment in question" do
    "The conversation that led to this assignment:\n#{micro_cluster_agent_log.transcript.to_json}"
  end

  def micro_cluster
    @micro_cluster ||= micro_cluster_agent_log.owner
  end

  def macro_cluster
    @macro_cluster ||= MacroCluster.find(micro_cluster_agent_log.extra_data["cluster_id"])
  end
end
