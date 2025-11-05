require "csv"

class PenAndInkSuggester
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript
  include ConfigureToken

  LIMIT = 150

  def initialize(user, extra_user_input = nil)
    self.user = user
    self.extra_user_input = extra_user_input
    transcript << { user: prompt }
    transcript << { user: extra_user_prompt } if extra_user_input.present?
  end

  def perform
    chat_completion(openai: "gpt-4.1-mini")
    response =
      if [message, ink_id, pen_id].all?(&:present?)
        { message:, ink: ink_id, pen: pen_id }
      else
        { message: "Sorry, that didn't work. Please try again!" }
      end
    agent_log.update(extra_data: response)
    agent_log.waiting_for_approval!
    response
  end

  def agent_log
    @agent_log ||= AgentLog.create!(name: self.class.name, transcript: [], owner: user)
  end

  function :record_suggestion,
           "Output for the end user. Must contain a markdown formatted suggestion for a pen and ink combination,
    along with the IDs of the suggested pen and ink.",
           suggestion: {
             type: "string",
             description: "Markdown formatted pen and ink suggestion",
             required: true
           },
           ink_id: {
             type: "integer",
             description: "ID of the suggested ink",
             required: true
           },
           pen_id: {
             type: "integer",
             description: "ID of the suggested pen",
             required: true
           } do |arguments|
    self.message = arguments[:suggestion]
    self.ink_id = arguments[:ink_id]
    self.pen_id = arguments[:pen_id]

    ink = inks.find { |ink| ink.id == ink_id }
    pen = pens.find { |pen| pen.id == pen_id }
    if ink && pen && message.present?
      stop_tool_calls_and_respond!
    elsif ink.blank? && pen.blank?
      "Please try again. Both the pen and ink IDs are invalid."
    elsif ink.blank?
      "Please try again. The ink ID is invalid."
    elsif pen.blank?
      "Please try again. The pen ID is invalid."
    elsif message.blank?
      "Please try again. The suggestion message is blank."
    end
  end

  private

  attr_accessor :user, :message, :ink_id, :pen_id, :extra_user_input

  def prompt
    <<~MESSAGE
      Given the following fountain pens:
      #{pen_data}

      Given the following inks:
      #{ink_data}

      Which combination of ink and fountain pen should I use and why? The rules to pick are as follows:

      * Prefer items that have either never been used, rarely used, or used a long time ago.
      * Also suggest items that have been used a lot.
      * Make only one suggestion.

      Use the `record_suggestion` function to return the suggestion. Provide a detailed reasoning for your
      choice in the suggestion message as well as the IDs of the suggested pen and ink. Follow these rules
      for the suggestion message:

      * Use markdown formatting.
      * Bullet list for the pen and ink chosen at the top (markdown formatted)
      * Keep the reasoning short and to the point.
      * Do not mention usage and daily usage count if they are zero.
      * Use the ink tags and description as part of the reasoning, but do not mention them directly.
      * Do not mention the pen and ink IDs in the suggestion message.
    MESSAGE
  end

  def extra_user_prompt
    "IMPORTANT: Take extra care to follow these additional instructions:\n#{extra_user_input}"
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
        "type",
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
            ink.kind,
            last_usage,
            ink.usage_count,
            ink.daily_usage_count,
            (ink.tag_names + ink.cluster_tags).uniq.join(","),
            ink.cluster_description || ""
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

        rel
      end
  end
end
