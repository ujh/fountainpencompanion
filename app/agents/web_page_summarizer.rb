class WebPageSummarizer
  include RubyLlmAgent

  MODEL_ID = "gpt-4.1-mini"
  MAX_INPUT_CHARS = 500_000

  SYSTEM_DIRECTIVE = <<~TEXT
    You will be given the raw HTML of a web page. Your task is to summarize the page
    and return the summary in a human-readable format. The summary should include
    the title, description, and any other relevant information that can be extracted.
  TEXT

  def initialize(parent_agent_log, raw_html)
    @parent_agent_log = parent_agent_log
    @raw_html = raw_html
  end

  def perform
    response = ask(raw_html[0, MAX_INPUT_CHARS])
    agent_log.waiting_for_approval!
    response.content
  end

  def agent_log = find_or_create_agent_log(parent_agent_log)

  private

  attr_reader :parent_agent_log, :raw_html
end
