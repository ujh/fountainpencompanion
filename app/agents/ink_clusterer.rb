class InkClusterer
  include Raix::ChatCompletion
  include Raix::FunctionDispatch

  SYSTEM_DIRECTIVE = <<~TEXT
    You are a clustering algorithm that groups similar inks together based on their properties.

    You will be given a ink and asked to find the most similar ink cluster in the database and
    assign the ink to that cluster. If no similar cluster is found, you will be asked to create a new cluster.
  TEXT

  def initialize(micro_cluster)
    self.micro_cluster = micro_cluster
    transcript << { system: SYSTEM_DIRECTIVE }
    transcript << { user: micro_cluster_data }
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4o-mini")
    save_transcript
  end

  private

  attr_accessor :micro_cluster

  def save_transcript
    AgentLog.create!(name: self.class.name, transcript:)
  end

  def micro_cluster_data
    data = { id: micro_cluster.id, names: micro_cluster.all_names }.to_json

    "This is the data for the ink to cluster: #{data}"
  end

  function :similarity_search,
           "Find the 10m most similar ink clusters by consine distance",
           search_string: {
             type: "string"
           } do |arguments|
    similar_clusters = MacroCluster.embedding_search(arguments[:search_string])
    similar_clusters.map do |data|
      cluster = data.cluster
      { id: cluster.id, name: cluster.name, distance: data.distance, synonyms: cluster.synonyms }
    end
  end

  function :assign_to_cluster,
           "Assign ink to existing cluster",
           ink_id: {
             type: "integer"
           },
           cluster_id: {
             type: "integer"
           } do |arguments|
    ink_id = arguments[:ink_id].to_i
    micro_cluster = MicroCluster.find(ink_id)
    cluster_id = arguments[:cluster_id].to_i
    cluster = MacroCluster.find(cluster_id)
    puts "Assigning #{micro_cluster.id} to #{cluster.id} - #{cluster.name}"
    stop_looping!
  end

  function :create_new_cluster,
           "Create a new cluster for this ink",
           ink_id: {
             type: "integer"
           } do |arguments|
    ink_id = arguments[:ink_id].to_i
    micro_cluster = MicroCluster.find(ink_id)
    puts "Creating new cluster for #{micro_cluster.id}"
    stop_looping!
  end
end
