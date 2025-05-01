module AgentTranscript
  extend ActiveSupport::Concern

  def agent_log
    raise NotImplementedError
  end

  def transcript
    @transcript ||= Transcript.new(agent_log)
  end

  class Transcript
    include Enumerable

    def initialize(agent_log)
      @transcript = []
      @agent_log = agent_log
    end

    def set!(data)
      @transcript = data.map(&:deep_symbolize_keys)
    end

    def <<(entry)
      @transcript << entry
      @agent_log.update(transcript: @transcript)
    end

    def each(&)
      @transcript.each(&)
    end

    def flatten
      @transcript.flatten
    end
  end
end
