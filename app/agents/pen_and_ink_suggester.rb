require "csv"

class PenAndInkSuggester
  include RubyLlmAgent

  class RecordSuggestion < RubyLLM::Tool
    description "Output for the end user. Must contain a markdown formatted suggestion for a pen and ink combination, " \
                  "along with the IDs of the suggested pen and ink."

    param :suggestion, desc: "Markdown formatted pen and ink suggestion"
    param :ink_id, type: "integer", desc: "ID of the suggested ink"
    param :pen_id, type: "integer", desc: "ID of the suggested pen"

    attr_accessor :inks, :pens, :message, :result_ink_id, :result_pen_id

    def initialize(inks, pens)
      self.inks = inks
      self.pens = pens
    end

    def execute(suggestion:, ink_id:, pen_id:)
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
  end

  LIMIT = 50
  LIMIT_PATRON = 100
  LIMIT_ADMIN = 200
  MAX_PER_DAY = 20
  MAX_PER_DAY_PATRON = 50

  def initialize(user, extra_user_input = nil, rejected_suggestions = [])
    self.user = user
    self.extra_user_input = extra_user_input
    self.rejected_suggestions = rejected_suggestions || []
  end

  def perform
    response =
      if can_perform?
        ask(user_prompt)
        tool = record_suggestion_tool
        if [tool.message, tool.result_ink_id, tool.result_pen_id].all?(&:present?)
          { message: tool.message, ink: tool.result_ink_id, pen: tool.result_pen_id }
        else
          { message: "Sorry, that didn't work. Please try again!" }
        end
      else
        { message: out_of_requests_message }
      end
    agent_log.update(extra_data: response)
    agent_log.waiting_for_approval!
    response
  end

  def agent_log = find_or_create_agent_log(user)

  private

  attr_accessor :user, :extra_user_input, :rejected_suggestions

  def model_id
    premium? ? "gpt-4.1" : "gpt-4.1-mini"
  end

  def system_directive = ""

  def record_suggestion_tool
    @record_suggestion_tool ||= RecordSuggestion.new(inks, pens)
  end

  def tools
    [record_suggestion_tool]
  end

  def user_prompt
    parts = [prompt]
    parts << additional_premium_prompt if premium?
    parts << extra_user_prompt if extra_user_input.present?
    parts << rejected_suggestions_prompt if rejected_suggestions.present?
    parts.join("\n\n")
  end

  # Build the "rejected suggestions" instruction server-side from the
  # validated {ink_id, pen_id} pairs. Attacker-controlled free-form text
  # cannot reach the LLM through this path.
  def rejected_suggestions_prompt
    "The following suggestions were rejected. Do not recommend them again:\n" \
      "#{JSON.generate(rejected_suggestions)}"
  end

  def prompt
    <<~MESSAGE
      Given the following fountain pens:
      #{pen_data}

      #{average_pen_usage}

      Given the following inks:
      #{ink_data}

      #{average_ink_usage}

      Which combination of ink and fountain pen should I use and why? The rules to pick are as follows:

      * Suggest only one fountain pen and one ink.
      * Strike a balance between novelty and favorites.
        * Novelty: Prefer items that have not been used recently or frequently.
        * Favorites: Consider items that I have used more often in the past.
        * Lean heavier towards novelty if you have to choose.

      Use the `record_suggestion` function to return the suggestion. Provide a detailed reasoning for your
      choice in the suggestion message as well as the IDs of the suggested pen and ink. Follow these rules
      for the suggestion message:

      * Use markdown formatting.
      * Bullet list for the pen and ink chosen at the top (markdown formatted)
      * Keep the reasoning short and to the point, but do not mention the rules directly.
      * Do not mention usage and daily usage count if they are zero.
      * Use the ink tags and description as part of the reasoning, but do not mention them directly.
      * Do not mention the pen and ink IDs in the suggestion message.
    MESSAGE
  end

  def additional_premium_prompt
    currently_inked = user.currently_inkeds.active.to_csv
    <<~MESSAGE
      Below is the list of currently inked pens in my collection:
      #{currently_inked}

      When picking a new pen and ink combination, take these into account and
      prefer combinations that do not overlap with the currently inked pens
      and inks. Prefer a variety of ink colors and nib sizes.
    MESSAGE
  end

  def extra_user_prompt
    "IMPORTANT: Take extra care to follow these additional instructions:\n#{extra_user_input}"
  end

  def average_pen_usage
    average_usage = (pens.sum(&:usage_count) / pens.size.to_f).round(2)
    average_daily_usage = (pens.sum(&:daily_usage_count) / pens.size.to_f).round(2)
    average_last_used_ago =
      pens.sum do |pen|
        last_used_on = pen.last_used_on || Date.today.advance(years: -1)
        (Date.today - last_used_on).to_i
      end / pens.size.to_f
    average_last_used_ago = time_ago_in_words(Date.today.advance(days: -average_last_used_ago))
    stats = { average_usage:, average_daily_usage:, average_last_used_ago: }
    "Pens have the following average statistics:\n#{stats.to_json}"
  rescue StandardError
    ""
  end

  def average_ink_usage
    average_usage = (inks.sum(&:usage_count) / inks.size.to_f).round(2)
    average_daily_usage = (inks.sum(&:daily_usage_count) / inks.size.to_f).round(2)
    average_last_used_ago =
      inks.sum do |ink|
        last_used_on = ink.last_used_on || Date.today.advance(years: -1)
        (Date.today - last_used_on).to_i
      end / inks.size.to_f
    average_last_used_ago = time_ago_in_words(Date.today.advance(days: -average_last_used_ago))
    stats = { average_usage:, average_daily_usage:, average_last_used_ago: }
    "Inks have the following average statistics:\n#{stats.to_json}"
  rescue StandardError
    ""
  end

  def time_ago_in_words(date)
    ActionController::Base.helpers.time_ago_in_words(date)
  end

  def pen_data
    CSV.generate do |csv|
      csv << ["pen id", "fountain pen name", "last usage", "usage count", "daily usage count"]
      pens
        .shuffle
        .take(limit)
        .each do |pen|
          last_usage = (pen.last_used_on ? time_ago_in_words(pen.last_used_on) : "never")
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
        .take(limit)
        .each do |ink|
          last_usage = (ink.last_used_on ? time_ago_in_words(ink.last_used_on) : "never")
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
      user.collected_inks.active.includes(
        :currently_inkeds,
        :usage_records,
        micro_cluster: {
          macro_cluster: :brand_cluster
        },
        newest_currently_inked: :last_usage
      )
  end

  def today_usage_count
    AgentLog
      .where(name: self.class.name, owner: user)
      .where("created_at >= ?", Time.current.beginning_of_day)
      .count
  end

  def can_perform?
    limit = premium? ? MAX_PER_DAY_PATRON : MAX_PER_DAY
    today_usage_count < limit
  end

  def out_of_requests_message
    if premium?
      "You have reached your daily limit of #{MAX_PER_DAY_PATRON} suggestions. Please try again tomorrow."
    else
      "You have reached your daily limit of #{MAX_PER_DAY} suggestions. Consider becoming a [Patron](https://www.patreon.com/bePatron?u=6900241) for a higher limit!"
    end
  end

  def limit
    return LIMIT_ADMIN if user.admin?

    premium? ? LIMIT_PATRON : LIMIT
  end

  def premium?
    user.patron? || user.admin?
  end
end
