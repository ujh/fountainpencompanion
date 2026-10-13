module Bench
  module Suggester
    module Checks
      module Outcome
        SUGGESTION = "suggestion"
        PRECHECK = "precheck"
        ERROR = "error"
        MESSAGE_ONLY = "message_only"

        def self.call(extra_data)
          extra_data = (extra_data || {}).to_h.stringify_keys
          if extra_data["pen"].present? && extra_data["ink"].present?
            SUGGESTION
          elsif extra_data.key?("precheck")
            PRECHECK
          elsif error?(extra_data)
            ERROR
          else
            MESSAGE_ONLY
          end
        end

        def self.error?(extra_data)
          extra_data["error"].present? || extra_data["status"] == "error" ||
            extra_data["message"] == PenAndInkSuggester::ERROR_MESSAGE
        end

        private_class_method :error?
      end
    end
  end
end
