module InkSimilaritySearch
  extend ActiveSupport::Concern

  def agent_log
    raise NotImplementedError
  end

  included do
    function :ink_similarity_search,
             "Find the 20 most similar ink clusters by cosine distance",
             search_string: {
               type: "string"
             } do |arguments|
      similar_clusters = MacroCluster.embedding_search(arguments[:search_string]).take(20)
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

    fuction :ink_full_text_search,
            "Fallback search, when results using similarity search inconclusive. Finds inks by full text search",
            search_string: {
              type: "string"
            } do |arguments|
      similar_clusters = MacroCluster.full_text_search(arguments[:search_string])
      similar_clusters.map do |cluster|
        data = { id: cluster.id, name: cluster.name, synonyms: cluster.synonyms }
        data[:color] = cluster.color if cluster.color.present?
        data
      end
    end
  end
end
