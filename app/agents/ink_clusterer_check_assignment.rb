class InkClustererCheckAssignment
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript

  SYSTEM_DIRECTIVE = <<~TEXT
    You are reviewing the result of a clustering algorithm that clusters inks,
    creates new clusters or ignores them. Here the algorithm suggested that the
    ink should assigned to an existing cluster.

    You are tasked with checking if the assignment is correct. You are given
    the ink, the cluster it is assigned to, and the reasoning of the algorithm.

    Inks should be assigned to a cluster when:
    * The ink is a different spelling of the cluster
    * The ink is a translation of the cluster
    * Some parts of the name were added or removed, but it is still definitely the same ink

    When both the ink and the cluster have an RGB color, a similar color is a good
    indicator that the assignment is correct.

    You can search the web for the ink. When you do that keep the following in mind:
    * The results might not even contain the ink name. You need to double check that the ink name is actually present.

    You can search the internal database using the similarity search function.
    * The similarity is based on vector embeddings. The smaller the number the closer they are.
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
          follow_up_action: agent_log.extra_data["action"],
          follow_up_action_explanation: agent_log.extra_data["explanation_of_decision"]
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

  function :approve_assignment,
           "Approve the assignment of the ink to the cluster",
           explanation_of_decision: {
             type: "string",
             description: "Explanation of why the assignment is correct"
           } do |arguments|
    agent_log.update(
      extra_data: {
        action: "approve",
        explanation_of_decision: arguments[:explanation_of_decision]
      }
    )
    stop_looping!
  end

  function :reject_assignment,
           "Reject the assignment of the ink to the cluster",
           explanation_of_decision: {
             type: "string",
             description: "Explanation of why the assignment is incorrect"
           } do |arguments|
    agent_log.update(
      extra_data: {
        action: "reject",
        explanation_of_decision: arguments[:explanation_of_decision]
      }
    )
    stop_looping!
  end

  function :log_of_clustering,
           "Log of the chat with the LLM that produced the cluster assignment in question" do
    "The conversation that led to this assignment:\n#{micro_cluster_agent_log.transcript.to_json}"
  end

  function :search_web, "Search the web", search_query: { type: "string" } do |arguments|
    search_query = "#{arguments[:search_query]} ink"
    search_results = GoogleSearch.new(search_query).perform
    search_summary = GoogleSearchSummarizer.new(search_query, search_results).perform
    "The search results for '#{search_query}' are:\n #{search_summary}"
  end

  function :similarity_search,
           "Find the 10 most similar ink clusters by cosine distance",
           search_string: {
             type: "string"
           } do |arguments|
    similar_clusters = MacroCluster.embedding_search(arguments[:search_string]).take(10)
    similar_clusters.map do |data|
      cluster = data.cluster
      data = {
        id: cluster.id,
        name: cluster.name,
        distance: data.distance,
        synonyms: cluster.synonyms
      }
      data[:color] = cluster.color if cluster.color.present?
      data
    end
  end

  def micro_cluster
    @micro_cluster ||= micro_cluster_agent_log.owner
  end

  def macro_cluster
    @macro_cluster ||= MacroCluster.find(micro_cluster_agent_log.extra_data["cluster_id"])
  end
end
