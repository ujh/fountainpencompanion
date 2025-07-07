class WebPageSummarizer
  include Raix::ChatCompletion
  include AgentTranscript

  SYSTEM_DIRECTIVE = <<~TEXT
    You will be given the raw HTML of a web page. Your task is to summarize the page
    and return the summary in a human-readable format. The summary should include
    the title, description, and any other relevant information that can be extracted.
  TEXT

  def initialize(parent_agent_log, raw_html)
    self.parent_agent_log = parent_agent_log
    self.raw_html = raw_html
    if agent_log.transcript.present?
      transcript.set!(agent_log.transcript)
    else
      transcript << { system: SYSTEM_DIRECTIVE }
      transcript << { user: raw_html }
    end
  end

  def perform
    summary = chat_completion(openai: "gpt-4o-mini")
    agent_log.waiting_for_approval!
    summary
  end

  def agent_log
    @agent_log ||= parent_agent_log.agent_logs.processing.where(name: self.class.name).first
    @agent_log ||= parent_agent_log.agent_logs.create!(name: self.class.name, transcript: [])
  end

  private

  attr_accessor :parent_agent_log, :raw_html
end
