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

  def initialize(micro_cluster_id)
    self.micro_cluster = MicroCluster.find(micro_cluster_id)
    if agent_log.transcript.present?
      transcript.set!(agent_log.transcript)
    else
      transcript << { system: SYSTEM_DIRECTIVE }
      transcript << { user: micro_cluster_data }
    end
  end

  def agent_log
    @agent_log ||= micro_cluster.agent_logs.ink_clusterer.processing.first
    @agent_log ||= micro_cluster.agent_logs.ink_clusterer.waiting_for_approval.first
    @agent_log ||= micro_cluster.agent_logs.create!(name: self.class.name, transcript: [])
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4.1")
    agent_log.update!(extra_data: extra_data)
    agent_log.waiting_for_approval!
  end

  def reject!
    agent_log.reject!
    micro_cluster.touch # Move it to the end of the queue
  end

  def approve!
    case agent_log.extra_data["action"]
    when "assign_to_cluster"
      micro_cluster.update!(macro_cluster_id: agent_log.extra_data["cluster_id"])
      UpdateMicroCluster.perform_async(micro_cluster.id)
    when "create_new_cluster"
      cluster = MacroCluster.create!
      micro_cluster.update!(macro_cluster_id: cluster.id)
      UpdateMicroCluster.perform_async(micro_cluster.id)
    when "ignore_ink"
      micro_cluster.update!(ignored: true)
    end
    agent_log.approve!
  end

  private

  attr_accessor :extra_data, :micro_cluster

  def transcript
    @transcript ||= Transcript.new(agent_log)
  end

  class Transcript
    include Enumerable

    def initialize(agent_log)
      @transcript = []
      @agent_log = agent_log
    end

    def set!(data)
      @transcript = data.map(&:deep_symbolize_keys)
    end

    def <<(entry)
      @transcript << entry
      @agent_log.update(transcript: @transcript)
    end

    def each(&)
      @transcript.each(&)
    end

    def flatten
      @transcript.flatten
    end
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
      { id: cluster.id, name: cluster.name, distance: data.distance, synonyms: cluster.synonyms }
    end
  end

  function :assign_to_cluster,
           "Assign ink to existing cluster",
           cluster_id: {
             type: "integer"
           } do |arguments|
    cluster_id = arguments[:cluster_id].to_i
    cluster = MacroCluster.find(cluster_id)
    self.extra_data = {
      msg: "Assigning #{micro_cluster_str} to #{cluster.id} - #{cluster.name}",
      action: "assign_to_cluster",
      cluster_id: cluster.id
    }
    stop_looping!
  end

  function :create_new_cluster, "Create a new cluster for this ink" do |_arguments|
    self.extra_data = {
      msg: "Creating new cluster for #{micro_cluster_str}",
      action: "create_new_cluster"
    }
    stop_looping!
  end

  function :ignore_ink, "Ignore this ink" do |_arguments|
    self.extra_data = { msg: "Ignoring #{micro_cluster_str}", action: "ignore_ink" }
    stop_looping!
  end

  function :known_brand, "Check if brand of ink is known" do
    cluster_brand_names = micro_cluster.all_names_as_elements.map { |ink| ink[:brand_name] }.uniq
    known_brand = MacroCluster.where(brand_name: cluster_brand_names).exists?
    known_brand ? "Yes, the ink brand is known." : "No, the ink brand is not known."
  end

  def micro_cluster_str
    "MicroCluster(#{micro_cluster.id})<#{micro_cluster.all_names.sort.join(", ")}>"
  end
end
