class GoogleSearchSummarizer
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript

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

  def initialize(search_term, search_results, owner)
    self.search_term = search_term
    self.search_results = search_results
    self.owner = owner
    transcript << { system: SYSTEM_DIRECTIVE }
    transcript << { user: search_term_prompt }
    transcript << { user: search_results_prompt }
  end

  def perform
    model = ENV["USE_OLLAMA"] == "true" ? "llama3.1" : "gpt-4.1-mini"
    chat_completion(openai: model)
    agent_log.update!(extra_data: { summary: summary })
    agent_log.approve!
    summary
  end

  def agent_log
    @agent_log ||= AgentLog.create!(name: self.class.name, transcript: [], owner: owner)
  end

  private

  attr_accessor :search_term, :search_results, :summary, :owner

  def search_term_prompt
    "The search was done for the following search term: #{search_term}"
  end

  def search_results_prompt
    "The search results are: #{search_results.to_json}"
  end

  function :summarize_search_results,
           "Summarize the search results",
           summary: {
             type: "string"
           } do |arguments|
    self.summary = arguments[:summary]
    stop_tool_calls_and_respond!
  end
end
