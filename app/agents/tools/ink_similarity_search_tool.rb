module Tools
  class InkSimilaritySearchTool < RubyLLM::Tool
    description "Find the 20 most similar ink clusters by cosine distance"

    parameter :search_string, description: "The search string to find similar inks"

    def execute(search_string:)
      similar_clusters = MacroCluster.embedding_search(search_string).take(20)
      similar_clusters.map do |data|
        cluster = data.cluster
        result = {
          id: cluster.id,
          name: cluster.name,
          distance: data.distance,
          synonyms: cluster.synonyms
        }
        result[:color] = cluster.color if cluster.color.present?
        result
      end
    end
  end
end
