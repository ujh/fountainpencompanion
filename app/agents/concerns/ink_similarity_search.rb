module InkSimilaritySearch
  extend ActiveSupport::Concern

  def agent_log
    raise NotImplementedError
  end

  included do
    function :ink_similarity_search,
             "Find the 10 most similar ink clusters by cosine distance",
             search_string: {
               type: "string"
             },
             extended_search: {
               type: "boolean",
               description: "Optional. Set to true to get 50 instead of 10 search results."
             } do |arguments|
      limit = arguments[:extended_search] ? 50 : 10
      similar_clusters = MacroCluster.embedding_search(arguments[:search_string]).take(limit)
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
  end
end
