module Tools
  class InkWebSearchTool < RubyLLM::Tool
    description "Search the web for an ink. The word 'ink' is automatically appended to the search query unless it already ends with it."

    def name = "search_web"

    param :search_query, desc: "The search query"

    attr_accessor :agent_log

    def initialize(agent_log)
      self.agent_log = agent_log
    end

    def execute(search_query:)
      search_query = search_query.strip
      search_query = "#{search_query} ink" unless search_query.match?(/\bink\z/i)
      search_summary = GoogleSearchSummarizer.new(search_query, parent_agent_log: agent_log).perform
      "The search results for '#{search_query}' are:\n #{search_summary}"
    end
  end
end
