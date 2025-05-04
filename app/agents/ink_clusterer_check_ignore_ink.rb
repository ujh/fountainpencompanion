class InkClustererCheckIgnoreInk
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript

  SYSTEM_DIRECTIVE = <<~TEXT
    You are reviewing the result of a clustering algorithm that clusters inks,
    or ignores them. Here the algorithm suggested that the ink should be ignored.

    Inks should be ignored when:

    * It is a mix of inks
    * It is an unidentified ink

    Note, that sometimes people create their own mixes of inks. These should be ignored. Often times these
    contain two ink names that are separated by a non-word character. Additionally, custom ink mixes
    most of the time do not use one of the know brand names (use the supplied function name to double check).

    Note, that sometimes people do not know the full name of an ink. These unidentified inks should also
    be ignored.

    If you are unsure you can search the web for it. Make sure to check the results
    to see if the ink name is actually present. The results might not even contain the ink name.
  TEXT

  def initialize(agent_log_id)
    self.micro_cluster_agent_log = AgentLog.find(agent_log_id)
    transcript << { system: SYSTEM_DIRECTIVE }
    transcript << { user: clustering_explanation }
    transcript << { user: micro_cluster_data }
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
    "Below is the reasoning of the AI for ignoring this ink:
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

  function :approve_cluster_creation, "Approve ignoring of this ink" do
    agent_log.update(extra_data: { action: "approve" })
    stop_looping!
  end

  function :reject_cluster_creation, "Reject ignoring of this ink" do
    agent_log.update(extra_data: { action: "reject" })
    stop_looping!
  end

  function :log_of_clustering,
           "Log of the chat with the LLM that produced the suggestion to ignore the ink" do
    "The conversation that led to the suggestion to ignore this ink:\n#{micro_cluster_agent_log.transcript.to_json}"
  end

  function :search_web, "Search the web", search_query: { type: "string" } do |arguments|
    search_query = "#{arguments[:search_query]} ink"
    search_results = GoogleSearch.new(search_query).perform
    "The search results for '#{search_query}' are:\n #{search_results.to_json}"
  end

  def micro_cluster
    @micro_cluster ||= micro_cluster_agent_log.owner
  end
end
