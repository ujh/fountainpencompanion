class PenAndInkSuggester
  class LegacyRecordSuggestion < RubyLLM::Tool
    description "Output for the end user. Must contain a markdown formatted suggestion for a pen and ink combination, " \
                  "along with the IDs of the suggested pen and ink."

    def name = "record_suggestion"

    param :suggestion, desc: "Markdown formatted pen and ink suggestion"
    param :ink_id, type: "integer", desc: "ID of the suggested ink"
    param :pen_id, type: "integer", desc: "ID of the suggested pen"

    attr_accessor :inks, :pens, :message, :result_ink_id, :result_pen_id

    def initialize(inks, pens)
      self.inks = inks
      self.pens = pens
    end

    def execute(suggestion:, ink_id:, pen_id:)
      return halt "Suggestion already recorded" if recorded?

      ink = inks.find { |i| i.id == ink_id }
      pen = pens.find { |p| p.id == pen_id }

      if ink && pen && suggestion.present?
        self.message = suggestion
        self.result_ink_id = ink_id
        self.result_pen_id = pen_id
        halt "Suggestion recorded"
      elsif ink.blank? && pen.blank?
        "Please try again. Both the pen and ink IDs are invalid."
      elsif ink.blank?
        "Please try again. The ink ID is invalid."
      elsif pen.blank?
        "Please try again. The pen ID is invalid."
      elsif suggestion.blank?
        "Please try again. The suggestion message is blank."
      end
    end

    def recorded?
      [message, result_ink_id, result_pen_id].all?(&:present?)
    end

    def result
      { message:, ink: result_ink_id, pen: result_pen_id } if recorded?
    end
  end
end
