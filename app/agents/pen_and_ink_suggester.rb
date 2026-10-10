require "csv"

class PenAndInkSuggester
  include RubyLlmAgent

  LIMIT = 50
  LIMIT_PATRON = 100
  LIMIT_ADMIN = 200
  MAX_PER_DAY = 20
  MAX_PER_DAY_PATRON = 50
  MAX_TOOL_CALLS = 12
  RESULT_KEYS = %i[message ink pen status].freeze
  ERROR_MESSAGE = "Sorry, that didn't work. Please try again!"
  NO_UNINKED_PENS_MESSAGE =
    "All your pens are currently inked (or you have none). Clean one up and try again."
  NO_FILLABLE_INKS_MESSAGE =
    "You have no inks to fill a pen with (swabs don't count). Add an ink and try again."
  SELECTION_END_MESSAGES = {
    no_compatible_pairs:
      "Your only inks are cartridges and none of your uninked pens takes them. " \
        "Clean a cartridge pen or add a bottle or sample and try again.",
    all_pairs_rejected:
      "You've turned down every combination of your uninked pens and inks. " \
        "Clean another pen or add an ink and try again."
  }.freeze

  def self.error_result
    { message: ERROR_MESSAGE, status: "error" }
  end

  def initialize(
    user,
    extra_user_input = nil,
    rejected_suggestions = [],
    queue_ms: nil,
    enforce_daily_limit: true,
    seed: nil
  )
    self.user = user
    self.extra_user_input = extra_user_input
    self.rejected_suggestions = rejected_suggestions || []
    self.queue_ms = queue_ms
    self.enforce_daily_limit = enforce_daily_limit
    self.seed = seed || SecureRandom.random_number(2**31)
  end

  def perform
    extra_data = run
    extra_data[:queue_ms] = queue_ms if queue_ms
    agent_log.update(extra_data:)
    agent_log.waiting_for_approval!
    extra_data.slice(*RESULT_KEYS)
  end

  def agent_log
    @agent_log ||= user.agent_logs.create!(name: self.class.name, transcript: [])
  end

  private

  attr_accessor :user,
                :extra_user_input,
                :rejected_suggestions,
                :queue_ms,
                :enforce_daily_limit,
                :seed

  def run
    if enforce_daily_limit
      daily_cap = DailyCap.new(user)
      return { message: daily_cap.message } if daily_cap.reached?
    end

    precheck = precheck_failure
    return { message: precheck[:message], precheck: precheck[:reason] } if precheck

    v2? ? suggest_v2 : suggest
  end

  def v2?
    extra_user_input.blank?
  end

  def suggest
    error = request_suggestion(user_prompt)
    result = legacy_record_suggestion_tool.result || self.class.error_result
    error ? result.merge(error:) : result
  end

  def suggest_v2
    if selection.ended?
      reason = selection.end_reason
      return { message: SELECTION_END_MESSAGES.fetch(reason), precheck: reason.to_s }
    end

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = request_suggestion(pick_prompt.user_message)
    latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    data = v2_result.merge(v2_log_data, latency_ms:)
    data[:violations] = record_suggestion_tool.violations if record_suggestion_tool.violations.any?
    error ? data.merge(error:) : data
  end

  def v2_result
    recorded = record_suggestion_tool.result
    return self.class.error_result unless recorded

    reasoning = PenAndInkSuggestion::ReasoningSanitizer.call(recorded[:reasoning])
    message =
      PenAndInkSuggestion::SuggestionMessage.new(
        pen: recorded[:pen],
        ink: recorded[:ink],
        nib_profile: snapshot.nib_profile(recorded[:pen]),
        reasoning:
      )
    { message: message.to_s, ink: recorded[:ink].id, pen: recorded[:pen].id, reasoning: }
  end

  def v2_log_data
    {
      constraints: nil,
      constraints_source: "none",
      shown_pen_ids: selection.shown_pen_ids,
      shown_ink_ids: selection.shown_ink_ids,
      rejected_pairs: rejected_suggestions,
      pins: [],
      notes: [],
      relaxations: [],
      seed:
    }
  end

  def request_suggestion(message)
    ask!(message)
    nil
  rescue RubyLlmAgent::ToolCallLimitExceeded, RubyLlmAgent::DecisionNotReachedError => e
    e.class.name.demodulize
  end

  def precheck_failure
    if (v2? ? candidate_selector.candidate_pens : pens).empty?
      { reason: "no_uninked_pens", message: NO_UNINKED_PENS_MESSAGE }
    elsif snapshot.fillable_inks.empty?
      { reason: "no_fillable_inks", message: NO_FILLABLE_INKS_MESSAGE }
    end
  end

  def model_id
    premium? ? "gpt-4.1" : "gpt-4.1-mini"
  end

  def tool_calls_mode = :one

  def max_tool_calls = MAX_TOOL_CALLS

  def system_directive
    v2? ? PenAndInkSuggestion::PickPrompt::SYSTEM_DIRECTIVE : ""
  end

  def legacy_record_suggestion_tool
    @legacy_record_suggestion_tool ||= LegacyRecordSuggestion.new(inks, pens)
  end

  def record_suggestion_tool
    @record_suggestion_tool ||= RecordSuggestion.new(selection, rejected_suggestions)
  end

  def tools
    [v2? ? record_suggestion_tool : legacy_record_suggestion_tool]
  end

  def candidate_selector
    @candidate_selector ||=
      PenAndInkSuggestion::CandidateSelector.new(
        snapshot:,
        rejected_pairs: rejected_suggestions,
        tier: slice_tier,
        seed:
      )
  end

  def selection
    @selection ||= candidate_selector.call
  end

  def pick_prompt
    PenAndInkSuggestion::PickPrompt.new(snapshot:, selection:, rejected_pairs: rejected_suggestions)
  end

  def slice_tier
    return :admin if user.admin?

    premium? ? :premium : :free
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
    <<~MESSAGE
      Below is the list of currently inked pens in my collection:
      #{currently_inked_data}

      When picking a new pen and ink combination, take these into account and
      prefer combinations that do not overlap with the currently inked pens
      and inks. Prefer a variety of ink colors and nib sizes.
    MESSAGE
  end

  def extra_user_prompt
    "IMPORTANT: Take extra care to follow these additional instructions:\n#{extra_user_input}"
  end

  def average_pen_usage
    stats = pens.map { |pen| snapshot.stats_for(pen) }
    average_usage = (stats.sum(&:usage_count) / pens.size.to_f).round(2)
    average_daily_usage = (stats.sum(&:daily_usage_count) / pens.size.to_f).round(2)
    average_last_used_ago =
      stats.sum do |pen_stats|
        last_used_on = pen_stats.last_used_on || Date.today.advance(years: -1)
        (Date.today - last_used_on).to_i
      end / pens.size.to_f
    average_last_used_ago = time_ago_in_words(Date.today.advance(days: -average_last_used_ago))
    stats = { average_usage:, average_daily_usage:, average_last_used_ago: }
    "Pens have the following average statistics:\n#{stats.to_json}"
  rescue StandardError
    ""
  end

  def average_ink_usage
    stats = inks.map { |ink| snapshot.stats_for(ink) }
    average_usage = (stats.sum(&:usage_count) / inks.size.to_f).round(2)
    average_daily_usage = (stats.sum(&:daily_usage_count) / inks.size.to_f).round(2)
    average_last_used_ago =
      stats.sum do |ink_stats|
        last_used_on = ink_stats.last_used_on || Date.today.advance(years: -1)
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
          stats = snapshot.stats_for(pen)
          last_usage = (stats.last_used_on ? time_ago_in_words(stats.last_used_on) : "never")
          csv << [pen.id, pen.name.inspect, last_usage, stats.usage_count, stats.daily_usage_count]
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
          stats = snapshot.stats_for(ink)
          last_usage = (stats.last_used_on ? time_ago_in_words(stats.last_used_on) : "never")
          csv << [
            ink.id,
            ink.name.inspect,
            ink.kind,
            last_usage,
            stats.usage_count,
            stats.daily_usage_count,
            (snapshot.tag_names(ink) + ink.cluster_tags).uniq.join(","),
            ink.cluster_description || ""
          ]
        end
    end
  end

  def currently_inked_data
    CSV.generate(col_sep: ";") do |csv|
      csv << [
        "Pen",
        "Ink",
        "Date Inked",
        "Date Cleaned",
        "Comment",
        "Daily Usage",
        "Last Used On",
        "Date Added"
      ]
      snapshot.active_inkings.each do |currently_inked|
        inking = snapshot.inking(currently_inked.id)
        csv << [
          currently_inked.pen_name,
          currently_inked.ink_name,
          currently_inked.inked_on,
          currently_inked.archived_on,
          currently_inked.comment,
          inking.usage_count,
          inking.last_usage_on,
          currently_inked.created_at.to_date.to_s
        ]
      end
    end
  end

  def snapshot
    @snapshot ||= PenAndInkSuggestion::CollectionSnapshot.new(user)
  end

  def pens
    @pens ||= snapshot.pens.reject { |pen| snapshot.inked?(pen) }
  end

  def inks
    snapshot.inks
  end

  def limit
    return LIMIT_ADMIN if user.admin?

    premium? ? LIMIT_PATRON : LIMIT
  end

  def premium?
    user.premium?
  end
end
