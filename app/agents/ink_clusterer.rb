class InkClusterer
  include Raix::ChatCompletion
  include Raix::FunctionDispatch

  SYSTEM_DIRECTIVE = <<~TEXT
    You are a clustering algorithm that groups similar inks together based on their properties.

    You will be given an ink and asked to execute one of the following actions:
    1. Find the most similar ink cluster in the database and assign the ink to that cluster.
       ONLY, if you are highly confident.
    2. Create a new cluster for the ink if no similar cluster is found.
    3. Ignore the ink if it is a mix of inks or an unidentified ink.
    4. Ask a human to handle the ink if you are unsure about the assignment.

    ONLY assign the ink to a cluster if you are confident that it belongs there. If you are not sure,
    you should rather ask a human to handle it than assigning it incorrectly.

    You are allowed to search more than once and do searches with certain parts of the ink name removed,
    if the results returned by the previous search did not result in similar enough results.

    Note, that sometimes people create their own mixes of inks. These should be ignored. Often times these
    contain two ink names that are separated by a non-word character. Additionally, custom ink mixes
    most of the time do not use one of the know brand names (use the supplied function name to double check).

    Note, that sometimes people do not know the full name of an ink. These unidentified inks should also
    be ignored.
  TEXT

  def initialize(micro_cluster)
    self.micro_cluster = micro_cluster
    transcript << { system: SYSTEM_DIRECTIVE }
    transcript << { user: micro_cluster_data }
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4.1")
    save_transcript
  end

  private

  attr_accessor :extra_data, :micro_cluster

  def save_transcript
    AgentLog.create!(name: self.class.name, owner: micro_cluster, transcript:, extra_data:)
  end

  def micro_cluster_data
    data = {
      id: micro_cluster.id,
      names: micro_cluster.all_names,
      names_as_elements: micro_cluster.all_names_as_elements
    }.to_json

    "This is the data for the ink to cluster: #{data}"
  end

  function :similarity_search,
           "Find the 10 most similar ink clusters by cosine distance",
           search_string: {
             type: "string"
           } do |arguments|
    similar_clusters = MacroCluster.embedding_search(arguments[:search_string])
    similar_clusters.map do |data|
      cluster = data.cluster
      {
        id: cluster.id,
        name: cluster.name,
        distance: data.distance,
        names_as_elements: cluster.all_names_as_elements
      }
    end
  end

  function :assign_to_cluster,
           "Assign ink to existing cluster",
           cluster_id: {
             type: "integer"
           } do |arguments|
    cluster_id = arguments[:cluster_id].to_i
    cluster = MacroCluster.find(cluster_id)
    self.extra_data = "Assigning #{micro_cluster_str} to #{cluster.id} - #{cluster.name}"
    stop_looping!
  end

  function :create_new_cluster, "Create a new cluster for this ink" do |_arguments|
    self.extra_data = "Creating new cluster for #{micro_cluster_str}"
    stop_looping!
  end

  function :ignore_ink, "Ignore this ink" do |_arguments|
    self.extra_data = "Ignoring #{micro_cluster_str}"
    stop_looping!
  end

  function :check_manually, "Ask a human to handle this ink" do |_arguments|
    self.extra_data = "Forwarding #{micro_cluster_str} to a human for review"
    stop_looping!
  end

  function :brand_names_with_synonyms, "List of known ink brands with synonyms" do
    BrandCluster.public.map { |c| { name: c.name, synonyms: c.synonyms } }
  end

  def micro_cluster_str
    "MicroCluster(#{micro_cluster.id})<#{micro_cluster.all_names.sort.join(", ")}>"
  end
end
