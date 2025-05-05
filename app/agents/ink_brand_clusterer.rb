class InkBrandClusterer
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript

  SYSTEM_DIRECTIVE = <<~TEXT
    Your task is to determine if the given ink belongs to one of the existing
    brands or if it is a new one. If it is a new one, you should create a new
    brand cluster for it. If it belongs to an existing brand, you should add it
    to the corresponding brand cluster.

    * You will receive the ink name and a list of synonyms.
    * You will also receive a list of existing brands with their names and synonyms.

    You can determine patterns in the names and synonyms of the inks and brands that
    can help you determine if the brand of the ink is a new one or already present
    in the system.

    Synonyms for ink include, but are not limited to:
    * Spelling variations or typos
    * Different translations of the same name
  TEXT

  def initialize(macro_cluster_id, evaluating: false)
    self.macro_cluster = MacroCluster.find(macro_cluster_id)
    self.evaluating = evaluating
    transcript << { system: SYSTEM_DIRECTIVE }
    transcript << { user: macro_cluster_data }
    transcript << { user: brands_data }
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4.1")
    agent_log.waiting_for_approval!
    agent_log
  end

  private

  attr_accessor :macro_cluster, :evaluating

  def agent_log
    @agent_log ||= macro_cluster.agent_logs.create!(name: self.class.name, transcript: [])
  end

  def macro_cluster_data
    data = { name: macro_cluster.name, name_details: macro_cluster.all_names_as_elements }
    synonyms = macro_cluster.synonyms
    data[:synonyms] = synonyms if synonyms.present?

    "The ink in question has the following details: #{data.to_json}"
  end

  def brands_data
    data =
      BrandCluster
        .includes(:macro_clusters)
        .all
        .map do |c|
          cd = { brand_cluster_id: c.id, name: c.name }
          synonyms = c.synonyms
          cd[:synonyms] = synonyms if synonyms.present?
          cd
        end
    if evaluating
      brand_name = macro_cluster.brand_name
      # Remove brand under question from the list of existing brands in the synonyms
      data =
        data.map do |brand|
          next brand unless brand[:synonyms].present?

          brand.merge(synonyms: brand[:synonyms].reject { |synonym| synonym == brand_name })
        end
      # Remove brand under question from the list of existing brands in the names. Use the first name
      # in the synonyms list as the name.
      data =
        data.map do |brand|
          next brand unless brand[:name] == brand_name

          brand.merge(name: (brand[:synonyms] || []).first)
        end
      # Remove brands with nil names
      data = data.reject { |brand| brand[:name].nil? }
    end

    "The following brands are already present in the system: #{data.to_json}"
  end

  function :add_to_brand_cluster,
           "Add ink to the brand cluster",
           brand_cluster_id: {
             type: "integer"
           } do |arguments|
    brand_cluster_id = arguments[:brand_cluster_id]
    brand_cluster = BrandCluster.find_by(id: brand_cluster_id)

    next "This brand_cluster_id does not exist. Please try again." unless brand_cluster

    UpdateBrandCluster.new(macro_cluster, brand_cluster).perform unless evaluating
    stop_looping!
    agent_log.update!(
      extra_data: {
        action: "add_to_brand_cluster",
        brand_cluster_id: brand_cluster.id
      }
    )
  end

  function :create_new_brand_cluster, "Create a new brand cluster" do
    CreateBrandCluster.new(macro_cluster).perform unless evaluating

    stop_looping!
    agent_log.update!(extra_data: { action: "create_new_brand_cluster" })
  end
end
