class GoogleSearchSummarizer
  include RubyLlmAgent

  class SummarizeSearchResults < RubyLLM::Tool
    description "Summarize the search results"

    parameters { string :summary, description: "The summary of the search results" }

    def execute(summary:)
      halt summary
    end
  end

  MODEL_ID = "gpt-4.1-mini"

  SYSTEM_DIRECTIVE = <<~TEXT
    You are tasked with summarizing the results of a Google search for further
    using in a different AI agent.

    Please summarize the results in a way that is easy to understand and
    provides a clear overview of the information found. The summary should
    include the most relevant points and any important details that may be
    useful for further processing.

    Include an indication of the number of results found and if that is a high
    or low number of results. Include an indication of the search term doesn't
    seem to refer to a real product.

    Also, include any alternative spellings or names that were found in the
    search results.
  TEXT

  def initialize(search_term, parent_agent_log:)
    @search_term = search_term
    @parent_agent_log = parent_agent_log
  end

  def perform
    response = ask(user_prompt)
    self.summary = response.content
    agent_log.update!(extra_data: { summary: summary })
    agent_log.approve!
    summary
  end

  def agent_log = find_or_create_agent_log(parent_agent_log)

  private

  attr_reader :search_term, :parent_agent_log
  attr_accessor :summary

  def tools = [SummarizeSearchResults]

  def search_results
    @search_results ||= GoogleSearch.new(search_term).perform
  end

  def user_prompt
    <<~TEXT
      The search was done for the following search term: #{search_term}

      The search results are: #{search_results.to_json}
    TEXT
  end
end
