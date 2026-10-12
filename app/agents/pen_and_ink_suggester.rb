class PenAndInkSuggester
  include RubyLlmAgent

  MAX_PER_DAY = 20
  MAX_PER_DAY_PATRON = 50
  MAX_TOOL_CALLS = 12
  RESULT_KEYS = %i[message ink pen pen_currently_inked currently_inked_id status].freeze
  ERROR_MESSAGE = "Sorry, that didn't work. Please try again!"
  NO_UNINKED_PENS_MESSAGE =
    "All your pens are currently inked (or you have none). Clean one up and try again."
  NAME_INKED_PEN_MESSAGE =
    "All your pens are currently inked (or you have none). Name one you'd like to re-ink next, " \
      "or clean one up and try again."
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
  FILTERED_END_MESSAGES = {
    no_compatible_pairs:
      "The pens and inks that fit your request don't fit together: cartridge inks need a pen " \
        "that takes cartridges. Change your request or try again without it.",
    all_pairs_rejected:
      "You've turned down every combination that fits your request; change your request or " \
        "try again without it."
  }.freeze
  PINNED_END_MESSAGES = {
    no_compatible_pairs:
      "The pens and inks you named don't fit together: cartridge inks need a pen that takes " \
        "cartridges. Name another pen or ink, or try again without naming one.",
    all_pairs_rejected:
      "You've turned down every combination of these; name another pen or ink, or try again " \
        "without the instruction."
  }.freeze
  CURRENTLY_INKED_NOTE = "Currently inked with %<ink>s — empty and clean it first."

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

    suggest
  end

  def instruction?
    extra_user_input.present?
  end

  def suggest
    ended = resolution_end || selection_end
    return log_data.merge(ended) if ended

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = request_suggestion(pick_prompt.user_message)
    latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    data = log_data.merge(recorded_result, latency_ms:)
    data[:violations] = record_suggestion_tool.violations if record_suggestion_tool.violations.any?
    error ? data.merge(error:) : data
  end

  def resolution_end
    return if candidate_selector.candidate_pens.any? || candidate_selector.pins(:pen).any?

    run_end(NAME_INKED_PEN_MESSAGE, "no_uninked_or_named_pens")
  end

  def selection_end
    return unless selection.ended?

    run_end(selection.end_message || end_messages.fetch(selection.end_reason), selection.end_reason)
  end

  def end_messages
    if resolution.pins?
      PINNED_END_MESSAGES
    elsif selection.constrained?
      FILTERED_END_MESSAGES
    else
      SELECTION_END_MESSAGES
    end
  end

  def run_end(message, reason)
    { :message => message, (extractor_ran? ? :ended : :precheck) => reason.to_s }
  end

  def extractor_ran? = instruction?

  def constraints
    extracted_constraints || PenAndInkSuggestion::Constraints.empty
  end

  def extracted_constraints
    return @extracted_constraints if defined?(@extracted_constraints)

    @extracted_constraints = (constraint_extractor.perform if instruction?)
  end

  def constraint_extractor
    @constraint_extractor ||=
      PenAndInkConstraintExtractor.new(
        extra_user_input,
        parent_agent_log: agent_log,
        previous_suggestion: rejected_suggestions.any?,
        names_found:
      )
  end

  def constraints_source
    return "none" unless instruction?

    extracted_constraints ? "extractor" : "fallback"
  end

  def fallback?
    constraints_source == "fallback"
  end

  def recorded_result
    recorded = record_suggestion_tool.result
    return self.class.error_result unless recorded

    pen = recorded[:pen]
    reasoning = PenAndInkSuggestion::ReasoningSanitizer.call(recorded[:reasoning])
    inking = snapshot.active_inking_for(pen)
    notes = pick_notes
    notes += [format(CURRENTLY_INKED_NOTE, ink: inking.collected_ink.short_name)] if inking
    message =
      PenAndInkSuggestion::SuggestionMessage.new(
        pen:,
        ink: recorded[:ink],
        nib_profile: snapshot.nib_profile(pen),
        notes:,
        reasoning:
      )
    result = {
      message: message.to_s,
      ink: recorded[:ink].id,
      pen: pen.id,
      pen_currently_inked: inking.present?
    }
    result[:currently_inked_id] = inking.id if inking
    result.merge(reasoning:, notes:)
  end

  def log_data
    data = {
      constraints: extracted_constraints&.to_h,
      constraints_source:,
      rejected_pairs: rejected_suggestions,
      pins: candidate_selector.log_pins,
      notes: resolution.notes,
      relaxations: [],
      seed:
    }
    data[:mentions] = mentions.map { |mention| mention.to_h.stringify_keys } if instruction?
    data[:extractor_error] = constraint_extractor.error if fallback?
    return data if resolution_end

    data.merge(
      shown_pen_ids: selection.shown_pen_ids,
      shown_ink_ids: selection.shown_ink_ids,
      notes: pick_notes,
      relaxations: selection.relaxations
    )
  end

  def pick_notes
    resolution.notes + selection.notes
  end

  def request_suggestion(message)
    ask!(message)
    nil
  rescue RubyLlmAgent::ToolCallLimitExceeded, RubyLlmAgent::DecisionNotReachedError => e
    e.class.name.demodulize
  end

  def precheck_failure
    if no_pens_to_suggest?
      { reason: "no_uninked_pens", message: no_uninked_pens_message }
    elsif snapshot.fillable_inks.empty?
      { reason: "no_fillable_inks", message: NO_FILLABLE_INKS_MESSAGE }
    end
  end

  def no_pens_to_suggest?
    !instruction? && candidate_selector.candidate_pens.empty?
  end

  def no_uninked_pens_message
    return NO_UNINKED_PENS_MESSAGE unless InstructionGate.new(user).allowed?

    NAME_INKED_PEN_MESSAGE
  end

  def model_id
    premium? ? "gpt-4.1" : "gpt-4.1-mini"
  end

  def tool_calls_mode = :one

  def max_tool_calls = MAX_TOOL_CALLS

  def system_directive = PenAndInkSuggestion::PickPrompt::SYSTEM_DIRECTIVE

  def record_suggestion_tool
    @record_suggestion_tool ||= RecordSuggestion.new(selection, rejected_suggestions)
  end

  def tools
    [record_suggestion_tool]
  end

  def candidate_selector
    @candidate_selector ||=
      PenAndInkSuggestion::CandidateSelector.new(
        snapshot:,
        rejected_pairs: rejected_suggestions,
        tier: slice_tier,
        seed:,
        resolution:,
        fallback: fallback?,
        constraints:
      )
  end

  def name_index
    @name_index ||= PenAndInkSuggestion::NameIndex.for(snapshot)
  end

  def mentions
    @mentions ||=
      if !instruction?
        []
      elsif extracted_constraints
        extractor_mentions
      else
        matcher_mentions
      end
  end

  def extractor_mentions
    %i[pen ink].flat_map do |side|
      extracted_constraints
        .mentions(side)
        .map { |text| PenAndInkSuggestion::MentionMatcher::Mention.new(text:, side:) }
    end
  end

  def matcher_mentions
    @matcher_mentions ||= PenAndInkSuggestion::MentionMatcher.call(name_index, extra_user_input)
  end

  def names_found
    @names_found ||=
      PenAndInkSuggestion::NameHints.call(snapshot, matcher_mentions, index: name_index)
  end

  def resolution
    @resolution ||=
      if instruction?
        PenAndInkSuggestion::NameResolver.call(snapshot, mentions, index: name_index)
      else
        PenAndInkSuggestion::NameResolver::Resolution.empty
      end
  end

  def selection
    @selection ||= candidate_selector.call
  end

  def pick_prompt
    PenAndInkSuggestion::PickPrompt.new(
      snapshot:,
      selection:,
      rejected_pairs: rejected_suggestions,
      notes: pick_notes,
      instruction: extra_user_input
    )
  end

  def slice_tier
    return :admin if user.admin?

    premium? ? :premium : :free
  end

  def snapshot
    @snapshot ||= PenAndInkSuggestion::CollectionSnapshot.new(user)
  end

  def premium?
    user.premium?
  end
end
