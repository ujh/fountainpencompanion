class PenAndInkConstraintExtractor
  class SetConstraints < RubyLLM::Tool
    description "Record the constraints read from the request. Call it exactly once."

    def name = "set_constraints"

    params do
      PenAndInkConstraintExtractor.add_fields(self, PenAndInkSuggestion::Constraints::TOP_FIELDS)
      object :pen, description: "Pen constraints", required: false do
        PenAndInkConstraintExtractor.add_fields(
          self,
          PenAndInkSuggestion::Constraints::SIDE_FIELDS.fetch(:pen)
        )
      end
      object :ink, description: "Ink constraints", required: false do
        PenAndInkConstraintExtractor.add_fields(
          self,
          PenAndInkSuggestion::Constraints::SIDE_FIELDS.fetch(:ink)
        )
      end
    end

    attr_accessor :constraints

    def execute(**arguments)
      return halt("Constraints already recorded") if constraints

      self.constraints = PenAndInkSuggestion::Constraints.from_h(arguments)
      halt "Constraints recorded"
    end
  end
end
