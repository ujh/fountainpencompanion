class PenAndInkConstraintExtractor
  class SetConstraintsJson < RubyLLM::Tool
    description "Record the constraints read from the request as one JSON object. Call it " \
                  "exactly once."

    def name = "set_constraints"

    param :constraints_json,
          desc:
            "A JSON object; leave out every field the request doesn't set: " \
              "#{PenAndInkSuggestion::Constraints.json_outline}"

    attr_accessor :constraints

    def execute(constraints_json:)
      return halt("Constraints already recorded") if constraints

      parsed = JSON.parse(constraints_json.to_s)
      unless parsed.is_a?(Hash)
        return "constraints_json must be a JSON object; call set_constraints again."
      end

      self.constraints = PenAndInkSuggestion::Constraints.from_h(parsed)
      halt "Constraints recorded"
    rescue JSON::ParserError
      "constraints_json is not valid JSON; call set_constraints again with a JSON object."
    end
  end
end
