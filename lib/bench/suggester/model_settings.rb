module Bench
  module Suggester
    class ModelSettings
      PROVIDER = "openai"
      REASONING_FAMILIES = /\A(?:o\d|gpt-(?:[5-9]|\d{2,}))/
      O_SERIES = /\Ao\d/
      LOWEST_EFFORTS = {
        "gpt-5" => "minimal",
        "gpt-5-mini" => "minimal",
        "gpt-5-nano" => "minimal"
      }.freeze
      DATE_SUFFIX = /-\d{4}-\d{2}-\d{2}\z/
      TEMPERATURE = 0

      attr_accessor :model_id, :requested_effort

      def initialize(model_id, reasoning_effort: nil)
        self.model_id = model_id
        self.requested_effort = reasoning_effort.presence
      end

      def reasoning?
        registered ? registered.reasoning? : REASONING_FAMILIES.match?(model_id)
      end

      def reasoning_effort
        return unless reasoning?

        requested_effort || lowest_effort
      end

      def temperature
        TEMPERATURE unless reasoning?
      end

      def register!
        return if registered

        RubyLLM.models.all << RubyLLM::Model::Info.new(
          id: model_id,
          name: model_id,
          provider: PROVIDER,
          capabilities: reasoning? ? %w[function_calling reasoning] : %w[function_calling],
          modalities: {
            input: %w[text],
            output: %w[text]
          }
        )
      end

      private

      def registered
        RubyLLM.models.find(model_id, PROVIDER)
      rescue RubyLLM::ModelNotFoundError
        nil
      end

      def lowest_effort
        return "low" if O_SERIES.match?(model_id)

        LOWEST_EFFORTS.fetch(model_id.sub(DATE_SUFFIX, ""), "none")
      end
    end
  end
end
