module Tools
  class InkFullTextSearchTool < RubyLLM::Tool
    description "Fallback search, when results using similarity search inconclusive. Finds inks by full text search"

    parameter :search_string, description: "The search string to find inks"

    def execute(search_string:)
      similar_clusters = MacroCluster.full_text_search(search_string)
      similar_clusters.map do |cluster|
        result = { id: cluster.id, name: cluster.name, synonyms: cluster.synonyms }
        result[:color] = cluster.color if cluster.color.present?
        result
      end
    end
  end
end
