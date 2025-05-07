module InkWebSearch
  extend ActiveSupport::Concern

  def agent_log
    raise NotImplementedError
  end

  included do
    function :search_web, "Search the web", search_query: { type: "string" } do |arguments|
      search_query = "#{arguments[:search_query]} ink"
      search_results = GoogleSearch.new(search_query).perform
      search_summary = GoogleSearchSummarizer.new(search_query, search_results, agent_log).perform
      "The search results for '#{search_query}' are:\n #{search_summary}"
    end
  end
end
