class InkClustererCheckIgnoreInk
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript

  SYSTEM_DIRECTIVE = <<~TEXT
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

    You can search the web for the ink. When you do that keep the following in mind:
    * The results might not even contain the ink name. You need to double check that the ink name is actually present.
    * Fewer results make it more likely that the ink does not exist.
    * More results make it more likely that the ink does exist.

    You can search the internal database using the similarity search function.
    * The similarity is based on vector embeddings. The smaller the number the closer they are.
    * Many results with a small distance but none that really fit usually mean that the ink is not a full name.
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
end
