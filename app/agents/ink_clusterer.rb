class InkClusterer
  include RubyLlmAgent
  include AfterCommitEverywhere

  class BaseTool < RubyLLM::Tool
    attr_accessor :micro_cluster, :agent_log

    def initialize(micro_cluster, agent_log)
      self.micro_cluster = micro_cluster
      self.agent_log = agent_log
    end

    private

    def missing_explanation?(explanation_of_decision)
      explanation_of_decision.blank?
    end

    def missing_explanation_error
      "Tool call not successful. Please supply an explanation of your decision."
    end

    def update_extra_data(data)
      agent_log.update!(extra_data: (agent_log.extra_data || {}).merge("action" => name, **data))
    end

    def micro_cluster_str
      "MicroCluster(#{micro_cluster.id})<#{micro_cluster.all_names.sort.join(", ")}>"
    end
  end

  class AssignToCluster < BaseTool
    description "Assign ink to existing cluster"

    param :cluster_id, type: "integer", desc: "The ID of the cluster to assign the ink to"
    param :explanation_of_decision,
          desc:
            "Explain why you are assigning the ink to this cluster and not creating a cluster or ignoring it"

    def execute(cluster_id:, explanation_of_decision:)
      return missing_explanation_error if missing_explanation?(explanation_of_decision)

      cluster = MacroCluster.find_by(id: cluster_id.to_i)
      return "Tool call not successful. Please supply a valid cluster ID." unless cluster

      update_extra_data(
        "msg" => "Assigning #{micro_cluster_str} to #{cluster.id} - #{cluster.name}",
        "explanation_of_decision" => explanation_of_decision,
        "cluster_id" => cluster.id
      )
      halt "Assigned to cluster #{cluster.id} - #{cluster.name}"
    end
  end

  class CreateNewCluster < BaseTool
    description "Create a new cluster for this ink"

    param :explanation_of_decision,
          desc:
            "Explain why you are creating a new cluster for this ink and not assigning it to an existing one or ignoring it"

    def execute(explanation_of_decision:)
      return missing_explanation_error if missing_explanation?(explanation_of_decision)

      update_extra_data(
        "msg" => "Creating new cluster for #{micro_cluster_str}",
        "explanation_of_decision" => explanation_of_decision
      )
      halt "Creating new cluster"
    end
  end

  class IgnoreInk < BaseTool
    description "Ignore this ink"

    param :explanation_of_decision,
          desc:
            "Explain why you are ignoring this ink and not assigning it to a cluster or creating a new one"

    def execute(explanation_of_decision:)
      return missing_explanation_error if missing_explanation?(explanation_of_decision)

      update_extra_data(
        "msg" => "Ignoring #{micro_cluster_str}",
        "explanation_of_decision" => explanation_of_decision
      )
      halt "Ignoring ink"
    end
  end

  class HandOverToHuman < BaseTool
    description "Hand over to human to do the assignment"

    def execute
      update_extra_data("msg" => "Handing over #{micro_cluster_str} to human")
      halt "Handing over to human"
    end
  end

  class KnownBrand < RubyLLM::Tool
    description "Check if brand of ink is known"

    attr_accessor :micro_cluster

    def initialize(micro_cluster)
      self.micro_cluster = micro_cluster
    end

    def execute
      known =
        MacroCluster
          .joins(:micro_clusters)
          .where(micro_clusters: { simplified_brand_name: micro_cluster.simplified_brand_name })
          .exists?
      if known
        "Yes, the ink brand is known."
      else
        "No, the ink brand is not known. Use the search function to double check for spelling mistakes, though!"
      end
    end
  end

  SHARED_RULES = <<~TEXT.freeze
    Evidence and ignore rules. When anything else in your instructions differs, these rules win.

    The "evidence" object in the ink data contains:
    * ink_users: how many distinct users entered this ink
    * brand_users: how many distinct users entered any ink of this brand
    * brand_catalogue_inks: how many inks of this brand are in the catalogue (existing clusters).
      Generic and placeholder brands ("Generic", "Unknown", "No name", "Unbranded" and similar) never
      count as catalogued brands, so for them it is always 0.

    Evidence rule: when ink_users is at least 3, or brand_catalogue_inks is at least 3, few or no web
    results are not evidence that the ink does not exist, because small makers often have little or no
    web presence. The evidence rule only cancels missing web results. On its own it is never evidence
    that the ink exists and never a reason to create a new cluster or to approve one (see the rules for
    creating a new cluster below). All reasons to ignore an ink below still apply. The evidence rule
    does not apply when brand_catalogue_inks is 0 and brand_users is 2 or less.

    Web results about a different product that only shares a word with the ink are neither evidence
    for nor against the ink. Treat them like no result, so the evidence rule and the specific product
    name exception below still apply.

    User and catalogue counts alone are never a reason to ignore an ink: new makers, collaborations and
    misspelled brand names start with few users and no catalogue inks. With no evidence either way,
    search the web before ignoring an ink.

    Creating a new cluster requires all of these:
    * No catalogue cluster matches the ink.
    * At least one web search for the ink was run.
    * A source names this exact ink: a web result, or the maker, a shop or a review found by the
      search. Only when no web result names this ink and the evidence rule applies may the name itself
      be the source, and only when it is a specific product name, not a line name, a recipe or mix
      name, a generic name or a colour-only name. A decision that relies on this exception must say so
      in its explanation.

    Assigning to an existing cluster: judge the name most users entered (the ink's main name), not a
    stray entry. Assign only when that name is the same ink, i.e. an exact match, a clear spelling
    variant, a translation, or the same name with or without the line name; an odd extra word in one
    entry (e.g. a suffix on the brand) does not prevent this. A similar-looking word is not enough. An
    unknown ink name that could combine or blend names of the maker's inks is a possible mix, not a
    typo. When in doubt between a typo and a different name, do not assign. A cluster whose names are
    the same name with different line or format words (bottle, cartridge, standard line, product codes)
    is one ink, and an exact match to that name is assigned to it.

    Reasons to ignore an ink:
    * It is a mix of inks, including known mixes and personal mixes, even when many users entered them
      under a catalogued brand. In lines made for mixing, everything the maker sells as its own product
      (a bottle or a pen bundle) is an ink, while named recipes that users mix themselves from the
      maker's published formulas are mixes. For Platinum Mixable, the base colours, the Dilution Liquid
      and specials sold as their own product are inks; the named recipes from Platinum's mixing
      formulas are mixes.
    * It is an unidentified ink: the user does not know which ink it is
    * It is an incomplete name, e.g. only the brand and line name, with the line name typed into the ink
      name field. A name that is the line of existing catalogue inks (the similarity search shows
      several "<brand> <line> <ink>" clusters whose line is this name, e.g. Stipula Calamo or Sailor
      Shikiori) is incomplete.
    * It is not an ink, e.g. a rollerball, ballpoint or gel refill, a pen or a cleaning solution
    * It is an ink someone made themselves (DIY), including inks with "custom" as the line name
    * It is a placeholder, a test entry or gibberish
    * It is a generic name without an identifiable maker
    * It is a colour-only name that matches no ink. A colour-only name is a brand (and optionally a
      line) plus only a plain colour word or colour phrase (e.g. Green, Dark Purple, Blue Black).
      Descriptive product names, such as names of woods, places, moods or objects, are not colour-only
      names even when they suggest a colour. A colour-only name matches an ink when the maker or the
      line sells an ink of exactly that name (e.g. Lamy Blue; a line's own colour name, even in another
      language, is not a colour-only name), or when a line is given and the catalogue has exactly one
      ink of that colour in that line: then the name is shorthand for that ink, so assign it there.
      Names that differ only in line or format words (bottle, cartridge, standard line, product codes)
      are one ink, not several.
      Otherwise ignore it; do not assign it to the brand's nearest named ink (Montblanc Green is not
      Montblanc Irish Green).
    * It is a one-person label: a name a user gives their own mixes or DIY inks that no maker or shop
      sells. Few users or no catalogue inks alone never make a brand a one-person label.

    Ink additives (shimmer, glitter and similar products that are mixed into ink) and dilution liquids
    sold as an ink product are inks. They are catalogued like inks and are not ignored as "not an ink";
    a dilution liquid is not a cleaning solution.
  TEXT

  MODEL_ID = "gpt-4.1"

  DEBOUNCE_WINDOW = 30.seconds

  SYSTEM_DIRECTIVE = <<~TEXT
    You are a clustering algorithm that groups similar inks together based on their properties.

    You will be given an ink and asked to execute one of the following actions:
    1. Find the most similar ink cluster in the database and assign the ink to that cluster.
    2. Create a new cluster for the ink if no similar cluster is found.
    3. Ignore the ink if it is a mix of inks or an unidentified ink.
    3.1 You can also ignore an ink if the user made a mistake and only provided the brand and line
        data of the ink. Usually, the line data is actually ink the ink name field by mistake.
    3.2 Products that are not actually inks, like rollerball refills, should also be ignored. Ink
        additives (shimmer, glitter and similar) are inks and are not ignored.
    3.3 Inks with "custom" as the line name should be ignored as well
    4. Hand over the ink to a human to do the assignment if you are not sure.

    ONLY assign the ink to a cluster if you are confident that it belongs there.
    If you are not confident, but sure that it is a real ink, rather create a new cluster for it.

    Before creating a new cluster make sure that you did a search for only the ink name to check
    if it was possibly created under a differnt brand or line, and at least one web search for the ink.
    Follow the rules for creating a new cluster given with the ink data.

    User and catalogue counts alone are never a reason to ignore an ink. When you have no evidence either
    way, e.g. an unknown brand with few users, search the web before ignoring the ink.

    If the ink has a color and the cluster you want to assign it to has a color as well,
    make sure that the colors are similar. However, this is not a requirement as the ink color
    sometimes gets set to an incorrect value by the user.

    You are allowed to search more than once and do searches with certain parts of the ink name removed,
    if the results returned by the previous search did not result in similar enough results.

    Note, that sometimes people create their own mixes of inks. These should be ignored. Often times these
    contain two ink names that are separated by a non-word character. Additionally, custom ink mixes
    most of the time do not use one of the know brand names (use the supplied function name to double check).
    The missing known brand name is only a sign of a mix when brand_catalogue_inks is below 3 and
    ink_users is below 3.

    Note, that sometimes people do not know the full name of an ink. These unidentified inks should also
    be ignored.

    If you are unsure if an ink exists, or is another name for an existing one you can search the web for it.
    The results can help you termine if you should assign the ink to an existing cluster, create a new one,
    or ignore it. Few things to keep in mind:
    1. The more results you get, the more likely it is that the ink is known.
    2. Even if there are many results, double check that the ink name is actually present. The results might
       not even contain the ink name.
    3. Follow the evidence rule given with the ink data: for some inks few or no results are not evidence
       that the ink does not exist.
  TEXT

  def initialize(micro_cluster_id, agent_log_id: nil)
    self.micro_cluster = MicroCluster.find(micro_cluster_id)
    self.agent_log_id = agent_log_id
  end

  def agent_log
    @agent_log = AgentLog.find(agent_log_id) if agent_log_id
    @agent_log ||= micro_cluster.agent_logs.ink_clusterer.processing.first
    @agent_log ||= micro_cluster.agent_logs.ink_clusterer.waiting_for_approval.first
    @agent_log ||= micro_cluster.agent_logs.create!(name: self.class.name, transcript: [])
  end

  def perform
    return if already_resolved?

    if recent_activity?
      RunInkClustererAgent.perform_in(DEBOUNCE_WINDOW, "InkClusterer", micro_cluster.id)
      return
    end

    if micro_cluster.collected_inks.present?
      ask!(user_prompt)
      agent_log.waiting_for_approval!
      schedule_follow_up!
    else
      agent_log.update(
        extra_data:
          (agent_log.extra_data || {}).merge(
            "action" => "reject",
            "explanation_of_decision" =>
              "The micro cluster has no inks in it. It is not possible to cluster an empty micro cluster."
          )
      )
      # Empty micro clusters can't be clustered and shouldn't reach a human
      # reviewer, so reject the log outright.
      agent_log.reject!
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
      extra_data = agent_log.extra_data
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
    AgentLog.transaction do
      agent_log.lock!
      return [] if agent_log.state == AgentLog::REJECTED

      to_reprocess = [micro_cluster]
      to_reprocess += Array(clean_up_rejected_approval!) if agent_log.approved?
      to_reprocess = to_reprocess.uniq.reject { |mi| mi.collected_inks.empty? }
      to_reprocess.map(&:touch)
      agent ? agent_log.reject_by_agent! : agent_log.reject!
      to_reprocess
    end
  end

  def approve!(agent: false)
    AgentLog.transaction do
      agent_log.lock!
      return if agent_log.approved?

      micro_cluster.lock!

      # The inks can move to another micro cluster between the run and the
      # approval (e.g. a typo gets fixed). A new macro cluster created for an
      # empty micro cluster would never get a name and stays orphaned.
      if agent_log.extra_data["action"] == "create_new_cluster" &&
           micro_cluster.collected_inks.empty?
        agent ? agent_log.reject_by_agent! : agent_log.reject!
        return
      end

      case agent_log.extra_data["action"]
      when "assign_to_cluster"
        micro_cluster.update!(macro_cluster_id: agent_log.extra_data["cluster_id"], ignored: false)
        after_commit { UpdateMicroCluster.perform_async(micro_cluster.id) }
      when "create_new_cluster"
        cluster = MacroCluster.create!(ink_name: SecureRandom.uuid)
        micro_cluster.update!(macro_cluster_id: cluster.id, ignored: false)
        after_commit { UpdateMicroCluster.perform_async(micro_cluster.id) }
      when "ignore_ink"
        previous_macro_cluster_id = micro_cluster.macro_cluster_id
        micro_cluster.update!(ignored: true, macro_cluster_id: nil)
        if previous_macro_cluster_id
          after_commit { UpdateMacroCluster.perform_async(previous_macro_cluster_id) }
        end
      when "hand_over_to_human"
        micro_cluster.touch # Move it to the end of the queue for now
      end
      agent ? agent_log.approve_by_agent! : agent_log.approve!
    end
  end

  private

  attr_accessor :micro_cluster, :agent_log_id

  def recent_activity?
    last_update = micro_cluster.collected_inks.maximum(:updated_at)
    last_update.present? && last_update > DEBOUNCE_WINDOW.ago
  end

  def already_resolved?
    return true if micro_cluster.ignored?
    return true if micro_cluster.macro_cluster_id.present?

    # Only an in-flight run (waiting for approval) should block a new run. The
    # ignored?/macro_cluster_id checks above already cover resolved states, and
    # APPROVED logs must not block re-clustering triggered by admin actions
    # (deleting a macro cluster, unignoring or unassigning a micro cluster).
    latest =
      micro_cluster.agent_logs.ink_clusterer.waiting_for_approval.order(updated_at: :desc).first
    return false unless latest

    micro_cluster.collected_inks.where("updated_at > ?", latest.updated_at).none?
  end

  def tools
    [
      AssignToCluster.new(micro_cluster, agent_log),
      CreateNewCluster.new(micro_cluster, agent_log),
      IgnoreInk.new(micro_cluster, agent_log),
      HandOverToHuman.new(micro_cluster, agent_log),
      KnownBrand.new(micro_cluster),
      Tools::InkSimilaritySearchTool.new,
      Tools::InkFullTextSearchTool.new,
      Tools::InkWebSearchTool.new(agent_log)
    ]
  end

  def user_prompt
    prompt = micro_cluster_data
    prompt += "\n\n#{processed_tries_data}" if processed_tries?
    prompt
  end

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
    entries = processed_tries.map { |log| processed_try_entry(log) }.compact

    "This ink was processed before #{processed_tries.count} times and the action taken
    was rejected. Therefore the following outcomes cannot be taken again:
    #{entries.map { |entry| "* #{entry}" }.join("\n")}"
  end

  def processed_try_entry(log)
    data = log.extra_data || {}
    summary = action_summary(data)
    return nil unless summary

    parts = [summary]
    if data["manual_rejection_note"].present?
      parts << "Rejection reason: #{data["manual_rejection_note"]}"
    elsif data["follow_up_action"] == "reject" && data["follow_up_action_explanation"].present?
      if data["explanation_of_decision"].present?
        parts << "AI reasoning: #{data["explanation_of_decision"]}"
      end
      parts << "Rejection reason: #{data["follow_up_action_explanation"]}"
    end
    parts.join(" | ")
  end

  def action_summary(data)
    case data["action"]
    when "assign_to_cluster"
      "Assigning ink to existing cluster with id #{data["cluster_id"]}. Assignments to other clusters can be considered."
    when "create_new_cluster"
      "Creating a new cluster for ink"
    when "ignore_ink"
      "Ignoring this ink"
    end
  end

  def micro_cluster_data
    data = {
      id: micro_cluster.id,
      names: micro_cluster.all_names,
      names_as_elements: micro_cluster.all_names_as_elements
    }
    data[:colors] = micro_cluster.colors if micro_cluster.colors.present?
    data[:evidence] = micro_cluster.clustering_evidence

    "#{SHARED_RULES}\nThis is the data for the ink to cluster: #{data.to_json}"
  end
end
