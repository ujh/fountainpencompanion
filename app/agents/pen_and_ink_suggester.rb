require "csv"

class PenAndInkSuggester
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript

  LIMIT = 50

  def initialize(user, ink_kind)
    self.user = user
    self.ink_kind = ink_kind
    transcript << { user: prompt }
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4.1")
    response = { message:, ink: ink_id, pen: pen_id }
    agent_log.update(extra_data: response)
    agent_log.waiting_for_approval!
    response
  end

  def agent_log
    @agent_log ||= AgentLog.create!(name: self.class.name, transcript: [], owner: user)
  end

  function :record_suggestion,
           suggestion: {
             type: "string",
             description: "Markdown formatted pen and ink suggestion"
           },
           ink_id: {
             type: "integer",
             description: "ID of the suggested ink"
           },
           pen_id: {
             type: "integer",
             description: "ID of the suggested pen"
           } do |arguments|
    self.message = arguments[:suggestion]
    self.ink_id = arguments[:ink_id]
    self.pen_id = arguments[:pen_id]

    ink = inks.find { |ink| ink.id == ink_id }
    pen = pens.find { |pen| pen.id == pen_id }
    if ink && pen
      stop_looping!
    elsif ink.blank? && pen.blank?
      "Please try again. Both the pen and ink IDs are invalid."
    elsif ink.blank?
      "Please try again. The ink ID is invalid."
    elsif pen.blank?
      "Please try again. The pen ID is invalid."
    end
  end

  private

  attr_accessor :user, :ink_kind, :message, :ink_id, :pen_id

  def prompt
    <<~MESSAGE
      Given the following fountain pens:
      #{pen_data}

      Given the following inks:
      #{ink_data}

      Which combination of ink and fountain pen should I use and why?

      Prefer items that have either never been used, rarely used, or used a long time ago.
      Also suggest items that have been used a lot.
      Make only one suggestion.
      Use markdown syntax for highlighting.
      Do not mention usage and daily usage count if they are zero.
      Use the ink tags and description as part of the reasoning, but do not mention them directly.
    MESSAGE
  end

  def pen_data
    CSV.generate do |csv|
      csv << ["pen id", "fountain pen name", "last usage", "usage count", "daily usage count"]
      pens
        .shuffle
        .take(LIMIT)
        .each do |pen|
          last_usage =
            if pen.last_used_on
              ActionController::Base.helpers.time_ago_in_words(pen.last_used_on)
            else
              "never"
            end
          csv << [pen.id, pen.name.inspect, last_usage, pen.usage_count, pen.daily_usage_count]
        end
    end
  end

  def ink_data
    CSV.generate do |csv|
      csv << [
        "ink id",
        "ink name",
        "last usage",
        "usage count",
        "daily usage count",
        "tags",
        "description"
      ]

      inks
        .shuffle
        .take(LIMIT)
        .each do |ink|
          last_usage =
            if ink.last_used_on
              ActionController::Base.helpers.time_ago_in_words(ink.last_used_on)
            else
              "never"
            end
          csv << [
            ink.id,
            ink.name.inspect,
            last_usage,
            ink.usage_count,
            ink.daily_usage_count,
            ink.cluster_tags.join(","),
            ink.cluster_description
          ]
        end
    end
  end

  def pens
    @pens ||=
      user
        .collected_pens
        .active
        .includes(:currently_inkeds, :usage_records, newest_currently_inked: :last_usage)
        .reject { |pen| pen.inked? }
  end

  def inks
    @inks ||=
      begin
        rel =
          user.collected_inks.active.includes(
            :currently_inkeds,
            :usage_records,
            micro_cluster: {
              macro_cluster: :brand_cluster
            },
            newest_currently_inked: :last_usage
          )
        rel = rel.where(kind: ink_kind) if ink_kind.present?
        rel
      end
  end
end
