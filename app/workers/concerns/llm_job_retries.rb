module LlmJobRetries
  extend ActiveSupport::Concern

  included do
    sidekiq_options retry: 3
    sidekiq_retry_in do |_count, exception|
      case exception
      when RubyLLM::BadRequestError, RubyLLM::ContextLengthExceededError
        :kill
      end
    end
  end
end
