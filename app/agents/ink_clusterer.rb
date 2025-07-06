class InkClusterer
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript
  include InkWebSearch
  include InkSimilaritySearch

  SYSTEM_DIRECTIVE = <<~TEXT
    You are a clustering algorithm that groups similar inks together based on their properties.

    You will be given an ink and asked to execute one of the following actions:
    1. Find the most similar ink cluster in the database and assign the ink to that cluster.
    2. Create a new cluster for the ink if no similar cluster is found.
    3. Ignore the ink if it is a mix of inks or an unidentified ink.
    3.1 You can also ignore an ink if the user made a mistake and only provided the brand and line
        data of the ink. Usually, the line data is actually ink the ink name field by mistake.
    3.2 Products that are not actually inks, like rollerball refills, should also be ignored.
    4. Hand over the ink to a human to do the assignment if you are not sure.

    ONLY assign the ink to a cluster if you are confident that it belongs there.
    If you are not confident, but sure that it is a real ink, rather create a new cluster for it.

    Before creating a new cluster make sure that you did a search for only the ink name to check
    if it was possibly created under a differnt brand or line.

    If the ink has a color and the cluster you want to assign it to has a color as well,
    make sure that the colors are similar. However, this is not a requirement as the ink color
    sometimes gets set to an incorrect value by the user.

    You are allowed to search more than once and do searches with certain parts of the ink name removed,
    if the results returned by the previous search did not result in similar enough results.

    Note, that sometimes people create their own mixes of inks. These should be ignored. Often times these
    contain two ink names that are separated by a non-word character. Additionally, custom ink mixes
    most of the time do not use one of the know brand names (use the supplied function name to double check).

    Note, that sometimes people do not know the full name of an ink. These unidentified inks should also
    be ignored.

    If you are unsure if an ink exists, or is another name for an existing one you can search the web for it.
    The results can help you termine if you should assign the ink to an existing cluster, create a new one,
    or ignore it. Few things to keep in mind:
    1. The more results you get, the more likely it is that the ink is known.
    2. Even if there are many results, double check that the ink name is actually present. The results might
       not even contain the ink name.
  TEXT

  def initialize(micro_cluster_id, agent_log_id: nil)
    self.micro_cluster = MicroCluster.find(micro_cluster_id)
    self.agent_log_id = agent_log_id
    if agent_log.transcript.present?
      transcript.set!(agent_log.transcript)
    else
      transcript << { system: SYSTEM_DIRECTIVE }
      transcript << { user: micro_cluster_data }
      transcript << { user: processed_tries_data } if processed_tries?
    end
  end

  def agent_log
    @agent_log = AgentLog.find(agent_log_id) if agent_log_id
    @agent_log ||= micro_cluster.agent_logs.ink_clusterer.processing.first
    @agent_log ||= micro_cluster.agent_logs.ink_clusterer.waiting_for_approval.first
    @agent_log ||= micro_cluster.agent_logs.create!(name: self.class.name, transcript: [])
  end

  def perform
    if micro_cluster.collected_inks.present?
      chat_completion(openai: "gpt-4.1")
      agent_log.update!(extra_data: extra_data)
      agent_log.waiting_for_approval!
      schedule_follow_up!
    else
      agent_log.update(
        extra_data: {
          "action" => "reject",
          "explanation_of_decision" =>
            "The micro cluster has no inks in it. It is not possible to cluster an empty micro cluster."
        }
      )
      agent_log.approve_by_agent!
    end
  end

  def schedule_follow_up!
    follow_up_agent =
      case (agent_log.extra_data || {})["action"]
      when "assign_to_cluster"
        CheckInkClustering::Assign
      when "create_new_cluster"
        CheckInkClustering::Create
      when "ignore_ink"
        CheckInkClustering::Ignore
      when "hand_over_to_human"
        CheckInkClustering::Human
      end

    if follow_up_agent.present?
      extra_data[:follow_up_agent] = follow_up_agent.name
      agent_log.update!(extra_data: extra_data)

      follow_up = extra_data[:follow_up_agent]
      RunInkClustererAgent.perform_async(follow_up, agent_log.id)
    else
      # No extra data, so something went wrong and it's best to try again.
      agent_log.destroy
      RunInkClustererAgent.perform_async("InkClusterer", micro_cluster.id)
    end
  end

  def reject!(agent: false)
    to_reprocess = [micro_cluster]
    to_reprocess += Array(clean_up_rejected_approval!) if agent_log.approved?
    to_reprocess = to_reprocess.uniq.reject { |mi| mi.collected_inks.empty? }
    to_reprocess.map(&:touch)
    agent ? agent_log.reject_by_agent! : agent_log.reject!
    to_reprocess
  end

  def approve!(agent: false)
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
    when "hand_over_to_human"
      micro_cluster.touch # Move it to the end of the queue for now
    end
    agent ? agent_log.approve_by_agent! : agent_log.approve!
  end

  private

  attr_accessor :extra_data, :micro_cluster, :agent_log_id

  def clean_up_rejected_approval!
    case agent_log.extra_data["action"]
    when "assign_to_cluster"
      micro_cluster.update!(macro_cluster_id: nil)
      micro_cluster
    when "create_new_cluster"
      if micro_cluster.macro_cluster
        micro_clusters = micro_cluster.macro_cluster.micro_clusters
        micro_cluster.macro_cluster.destroy
        micro_clusters
      else
        micro_cluster
      end
    when "ignore_ink"
      micro_cluster.update!(ignored: false)
      micro_cluster
    end
  end

  def processed_tries?
    processed_tries.exists?
  end

  def processed_tries
    micro_cluster.agent_logs.ink_clusterer.rejected.where("created_at < ?", agent_log.created_at)
  end

  def processed_tries_data
    data =
      processed_tries
        .map do |log|
          case log.extra_data["action"]
          when "assign_to_cluster"
            "Assigning ink to existing cluster with id #{log.extra_data["cluster_id"]}. Assignments to other clusters can be considered."
          when "create_new_cluster"
            "Creating a new cluster for ink"
          when "ignore_ink"
            "Ignoring this ink"
          end
        end
        .uniq

    "This ink was processed before #{processed_tries.count} times and the action taken
    was manually rejected. Therefore the following outcomes cannot be taken again:
    #{data.map { |str| "* #{str}" }.join("\n")}"
  end

  def micro_cluster_data
    data = {
      id: micro_cluster.id,
      names: micro_cluster.all_names,
      names_as_elements: micro_cluster.all_names_as_elements
    }
    data[:colors] = micro_cluster.colors if micro_cluster.colors.present?

    "This is the data for the ink to cluster: #{data.to_json}"
  end

  function :assign_to_cluster,
           "Assign ink to existing cluster",
           cluster_id: {
             type: "integer"
           },
           explanation_of_decision: {
             type: "string",
             description:
               "Explain why you are assigning the ink to this cluster and not creating a cluster or ignoring it"
           } do |arguments|
    cluster_id = arguments[:cluster_id].to_i
    cluster = MacroCluster.find_by(id: cluster_id)
    if cluster && arguments[:explanation_of_decision].present?
      self.extra_data = {
        msg: "Assigning #{micro_cluster_str} to #{cluster.id} - #{cluster.name}",
        action: "assign_to_cluster",
        explanation_of_decision: arguments[:explanation_of_decision],
        cluster_id: cluster.id
      }
      stop_tool_calls_and_respond!
    else
      "Tool call not successful. Please supply a valid cluster ID to assign the ink to as well as an explanation of your decision."
    end
  end

  function :create_new_cluster,
           "Create a new cluster for this ink",
           explanation_of_decision: {
             type: "string",
             description:
               "Explain why you are creating a new cluster for this ink and not assigning it to an existing one or ignoring it"
           } do |arguments|
    if arguments[:explanation_of_decision].present?
      self.extra_data = {
        msg: "Creating new cluster for #{micro_cluster_str}",
        action: "create_new_cluster",
        explanation_of_decision: arguments[:explanation_of_decision]
      }
      stop_tool_calls_and_respond!
    else
      "Tool call not successful. Please supply an explanation of your decision to create a new cluster for this ink."
    end
  end

  function :ignore_ink,
           "Ignore this ink",
           explanation_of_decision: {
             type: "string",
             description:
               "Explain why you are ignoring this ink and not assigning it to a cluster or creating a new one"
           } do |arguments|
    if arguments[:explanation_of_decision].present?
      self.extra_data = {
        msg: "Ignoring #{micro_cluster_str}",
        action: "ignore_ink",
        explanation_of_decision: arguments[:explanation_of_decision]
      }
      stop_tool_calls_and_respond!
    else
      "Tool call not successful. Please supply an explanation of your decision to ignore this ink."
    end
  end

  function :hand_over_to_human, "Hand over to human to do the assignment" do |_arguments|
    self.extra_data = {
      msg: "Handing over #{micro_cluster_str} to human",
      action: "hand_over_to_human"
    }
    stop_tool_calls_and_respond!
  end

  function :known_brand, "Check if brand of ink is known" do
    known_brand =
      MacroCluster
        .joins(:micro_clusters)
        .where(micro_clusters: { simplified_brand_name: micro_cluster.simplified_brand_name })
        .exists?
    if known_brand
      "Yes, the ink brand is known."
    else
      "No, the ink brand is not known. Use the search function to double check for spelling mistakes, though!"
    end
  end

  def micro_cluster_str
    "MicroCluster(#{micro_cluster.id})<#{micro_cluster.all_names.sort.join(", ")}>"
  end
end
