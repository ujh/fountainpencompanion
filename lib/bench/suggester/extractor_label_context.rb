module Bench
  module Suggester
    class ExtractorLabelContext
      attr_accessor :runs

      def initialize(runs:)
        self.runs = runs
      end

      def call(labels)
        labels.map do |label|
          run = !label.context? && first_runs[ExtractorLabel.normalise_text(label.text)]
          run ? label.with_context(user_id: run.user_id, as_of: run.created_at) : label
        end
      end

      private

      def first_runs
        @first_runs ||=
          runs.each_with_object({}) do |run, found|
            next if run.instruction.blank?

            text = run.instruction.first(WidgetsController::MAX_EXTRA_USER_INPUT_LENGTH)
            found[ExtractorLabel.normalise_text(text)] ||= run
          end
      end
    end
  end
end
