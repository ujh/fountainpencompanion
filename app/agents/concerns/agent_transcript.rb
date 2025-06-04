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
      @transcript = data.flatten.map(&:deep_symbolize_keys)
    end

    def <<(data)
      entries = data.is_a?(Array) ? data : [data]
      entries.each { |e| @transcript << e }
      role = entries.first[:role]
      if role == "assistant"
        %w[prompt_tokens completion_tokens total_tokens].each do |key|
          @agent_log.usage[key] += Thread.current[:chat_completion_response]["usage"][key]
        end
      end
      @agent_log.transcript = @transcript
      @agent_log.save
    end

    def each(&)
      @transcript.each(&)
    end

    def flatten
      @transcript.flatten
    end
  end
end
