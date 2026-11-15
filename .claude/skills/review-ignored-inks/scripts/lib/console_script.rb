require "json"

module IgnoredInksReview
  # Fills console_template.rb with the units of one production script.
  module ConsoleScript
    UNSAFE_CHARACTERS = /[\u007f-\u009f\u2028\u2029\p{Cf}]/

    module_function

    def render(template, run_id, part, summary, units)
      json = "[\n" + units.map { |u| "    #{generate_json(u)}" }.join(",\n") + "\n    ]"
      comment = ->(text) { text.to_s.gsub(/[[:cntrl:]]/, " ") }
      # Block form, so backslashes in the JSON are not read as substitution escapes.
      # The run id goes into the code as an inspected (escaped) string literal.
      template
        .sub("__RUN_LABEL__") { comment.(run_id) }
        .sub("__RUN_ID__") { run_id.to_s.inspect }
        .sub("__PART__") { comment.(part) }
        .sub("__SUMMARY__") { comment.(summary) }
        .sub("__DECISIONS__") { json }
    end

    def generate_json(value)
      JSON
        .generate(value)
        .gsub(UNSAFE_CHARACTERS) do |char|
          char.encode("UTF-16BE").unpack("n*").map { |unit| format("\\u%04x", unit) }.join
        end
    end
  end
end
