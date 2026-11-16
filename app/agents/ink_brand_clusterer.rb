class InkBrandClusterer
  include RubyLlmAgent

  class AddToBrandCluster < RubyLLM::Tool
    description "Add ink to the brand cluster"

    parameter :brand_cluster_id,
              type: "integer",
              description: "The ID of the brand cluster to add the ink to"

    attr_accessor :macro_cluster, :agent_log

    def initialize(macro_cluster, agent_log)
      self.macro_cluster = macro_cluster
      self.agent_log = agent_log
    end

    def execute(brand_cluster_id:)
      brand_cluster = BrandCluster.find_by(id: brand_cluster_id)

      return "This brand_cluster_id does not exist. Please try again." unless brand_cluster

      UpdateBrandCluster.new(macro_cluster, brand_cluster).perform
      agent_log.update!(
        extra_data: {
          action: "add_to_brand_cluster",
          brand_cluster_id: brand_cluster.id
        }
      )
      halt "Added to brand cluster #{brand_cluster.name}"
    end
  end

  class CreateNewBrandCluster < RubyLLM::Tool
    description "Create a new brand cluster"

    attr_accessor :macro_cluster, :agent_log

    def initialize(macro_cluster, agent_log)
      self.macro_cluster = macro_cluster
      self.agent_log = agent_log
    end

    def execute
      CreateBrandCluster.new(macro_cluster).perform
      agent_log.update!(extra_data: { action: "create_new_brand_cluster" })
      halt "Created new brand cluster"
    end
  end

  MODEL_ID = "gpt-4.1"

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

  def initialize(macro_cluster_id)
    self.macro_cluster = MacroCluster.find(macro_cluster_id)
  end

  def perform
    ask(user_prompt)
    agent_log.waiting_for_approval!
    agent_log
  end

  def agent_log = find_or_create_agent_log(macro_cluster)

  private

  attr_accessor :macro_cluster

  def tools
    [
      AddToBrandCluster.new(macro_cluster, agent_log),
      CreateNewBrandCluster.new(macro_cluster, agent_log)
    ]
  end

  def user_prompt
    "#{macro_cluster_data}\n\n#{brands_data}"
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

    "The following brands are already present in the system: #{data.to_json}"
  end
end
