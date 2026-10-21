# Merges triage, research, verify results and human overrides into
# RUN_DIR/decisions.json, the single source for render.rb and console.rb.
#
#   ruby finalize.rb RUN_DIR
#
# Precedence: override > research (changes only when the verifier confirmed)
# > triage. A change the verifier rejected becomes "unsure" and is marked
# disputed so the reviewer sees both sides.
#
# Decisions or overrides that console.rb cannot apply are listed in "invalid",
# and a merge source confirmed into more than one cluster in "merge_conflicts";
# console.rb refuses to run while either is non-empty.
require_relative "lib/common"

DECISION_VERDICTS = (IgnoredInksReview::CHANGE_VERDICTS + %w[keep_ignored unsure]).freeze

dir = IgnoredInksReview.run_dir(ARGV[0])
pending = IgnoredInksReview.pending(dir)
triage = IgnoredInksReview.results(dir, "triage")
research = IgnoredInksReview.results(dir, "research")
verify = IgnoredInksReview.results(dir, "verify")
overrides = IgnoredInksReview.overrides(dir)

incomplete = []
decisions =
  pending.map do |candidate|
    id = candidate["id"]
    base = {
      "id" => id,
      "name" => IgnoredInksReview.display_name(candidate),
      "names" => candidate["names"].map { |n| IgnoredInksReview.short_name(n) },
      "users" => candidate["users"],
      "inks" => candidate["inks"],
      "colors" => candidate["colors"],
      "assigned_macro" => candidate["assigned_macro"],
      "ignored_vs_prompt_change" => candidate["ignored_vs_prompt_change"] || "unknown",
      "history" =>
        candidate["clusterer_logs"]
          .first(3)
          .map do |l|
            [l["created"], l["action"], l["state"], l["follow_up_action"]].compact.join(" ")
          end
    }
    proposal = research[id] || triage[id]
    unless proposal
      incomplete << id
      next(
        base.merge(
          "verdict" => "unsure",
          "reason" => "Not reviewed (stage incomplete)",
          "source" => "none"
        )
      )
    end

    decision =
      base.merge(
        "verdict" => proposal["verdict"] == "research" ? "unsure" : proposal["verdict"],
        "category" => proposal["category"],
        "reason" => proposal["reasoning"] || proposal["reason"],
        "confidence" => proposal["confidence"],
        "evidence" => proposal["evidence"] || [],
        "cluster_id" => proposal["cluster_id"],
        "proposed_name" => proposal["proposed_name"],
        "group_with" => Array(proposal["group_with"]),
        "flags" => Array(proposal["flags"]),
        "source" => research[id] ? "research" : "triage"
      )
    incomplete << id if proposal["verdict"] == "research"

    if IgnoredInksReview::CHANGE_VERDICTS.include?(decision["verdict"])
      check = verify[id]
      if check.nil?
        incomplete << id
      else
        decision["verifier"] = {
          "verdict" => check["verdict"],
          "notes" => check["notes"] || check["reasoning"],
          "suggested_verdict" => check["suggested_verdict"],
          "suggested_cluster_id" => check["suggested_cluster_id"]
        }.compact
        decision["group_with"] |= Array(check["suggested_group_with"]) if check["verdict"] ==
          "confirm"
        if check["verdict"] == "reject"
          decision["disputed"] = true
          decision["proposed_verdict"] = decision["verdict"]
          decision["verdict"] = "unsure"
        end
      end
    end

    if (override = overrides[id])
      decision.merge!(override.slice("verdict", "cluster_id", "proposed_name", "category"))
      decision["group_with"] = Array(override["group_with"]) if override.key?("group_with")
      decision["human_note"] = override["note"]
      decision["source"] = "human"
      decision["disputed"] = false
    end
    decision.delete("category") unless decision["verdict"] == "keep_ignored"
    if decision["verdict"] == "assign" &&
         decision["cluster_id"] == decision.dig("assigned_macro", "id")
      decision["verdict"] = "unignore"
    end
    decision
  end

# Clusters outside this run that a create names in group_with join the run as
# members of that new cluster; the verifier has checked group_with already.
all_candidates = IgnoredInksReview.candidates(dir).to_h { |c| [c["id"], c] }
in_run = decisions.map { |d| d["id"] }
decisions
  .select { |d| d["verdict"] == "create" }
  .each do |lead|
    lead["group_with"].each do |other|
      next if in_run.include?(other) || !all_candidates.key?(other)

      candidate = all_candidates[other]
      in_run << other
      decisions << {
        "id" => other,
        "name" => IgnoredInksReview.display_name(candidate),
        "names" => candidate["names"].map { |n| IgnoredInksReview.short_name(n) },
        "users" => candidate["users"],
        "inks" => candidate["inks"],
        "colors" => candidate["colors"],
        "assigned_macro" => candidate["assigned_macro"],
        "ignored_vs_prompt_change" => candidate["ignored_vs_prompt_change"] || "unknown",
        "history" => [],
        "verdict" => "create",
        "reason" => "Same ink as MC #{lead["id"]} (group_with); pulled into this run",
        "confidence" => lead["confidence"],
        "evidence" => lead["evidence"],
        "group_with" => [lead["id"]],
        "flags" => ["pulled in via group_with"],
        "source" => "group"
      }
      next unless (override = overrides[other])

      decisions.last.merge!(override.slice("verdict", "cluster_id", "proposed_name", "category"))
      decisions.last["group_with"] = Array(override["group_with"]) if override.key?("group_with")
      decisions.last.merge!("human_note" => override["note"], "source" => "human")
      decisions.last.delete("category") unless decisions.last["verdict"] == "keep_ignored"
    end
  end

invalid = []
decisions.each do |d|
  problem =
    if !DECISION_VERDICTS.include?(d["verdict"])
      "unknown verdict #{d["verdict"].inspect}"
    elsif d["verdict"] == "keep_ignored" && !IgnoredInksReview::CATEGORIES.include?(d["category"])
      "keep_ignored needs a category (#{IgnoredInksReview::CATEGORIES.join(", ")}), got #{d["category"].inspect}"
    elsif d["verdict"] == "assign" && !d["cluster_id"].is_a?(Integer)
      "assign needs an integer cluster_id, got #{d["cluster_id"].inspect}"
    elsif d["verdict"] == "unignore" && !d["assigned_macro"]
      "unignore needs a cluster that still sits in a macro cluster; use assign or create"
    end
  invalid << { "id" => d["id"], "problem" => problem } if problem
end

# Micro clusters that are the same new ink share one new macro cluster.
creates = decisions.select { |d| d["verdict"] == "create" }.to_h { |d| [d["id"], d] }
parent = creates.keys.to_h { |id| [id, id] }
find = ->(id) { parent[id] == id ? id : (parent[id] = find.(parent[id])) }
creates.each_value do |d|
  d["group_with"].each { |other| parent[find.(d["id"])] = find.(other) if creates.key?(other) }
end
groups =
  creates
    .keys
    .group_by { |id| find.(id) }
    .to_h do |_, ids|
      key = "g#{ids.min}"
      lead = ids.map { |id| creates[id] }.max_by { |d| d["users"] }
      ids.each { |id| creates[id]["group"] = key }
      [key, { "ids" => ids.sort, "proposed_name" => lead["proposed_name"] }]
    end

dangling =
  creates.values.flat_map do |d|
    d["group_with"].reject { |o| creates.key?(o) }.map { |o| [d["id"], o] }
  end

# Confirmed merges, with owner overrides keyed by the pair id ("m<low>-<high>").
merges =
  IgnoredInksReview
    .results(dir, "merge")
    .values
    .map do |row|
      merge = row.slice("id", "verdict", "from", "into", "notes").merge("source" => "merge")
      if (override = overrides[row["id"]])
        merge.merge!(override.slice("verdict", "from", "into"))
        merge.merge!("human_note" => override["note"], "source" => "human")
      end
      merge
    end
merges.each do |m|
  problem =
    if !IgnoredInksReview::MERGE_VERDICTS.include?(m["verdict"])
      "unknown merge verdict #{m["verdict"].inspect}"
    elsif !m["from"].is_a?(Integer) || !m["into"].is_a?(Integer) || m["from"] == m["into"]
      "a merge needs two different integer cluster ids, got #{m["from"].inspect} -> #{m["into"].inspect}"
    end
  invalid << { "id" => m["id"], "problem" => problem } if problem
end
known_ids = decisions.map { |d| d["id"] } + merges.map { |m| m["id"] }
overrides.each_key do |id|
  next if known_ids.include?(id)

  invalid << {
    "id" => id,
    "problem" =>
      "override for an id that is not in this run (new merge pairs go into merge-seeds.json)"
  }
end

confirmed = merges.select { |m| m["verdict"] == "confirm" }
merge_conflicts =
  confirmed
    .group_by { |m| m["from"] }
    .select { |_, pairs| pairs.size > 1 }
    .map { |from, pairs| { "from" => from, "pairs" => pairs.map { |m| m["id"] } } }
target_of = confirmed.to_h { |m| [m["from"], m["into"]] }
final_target =
  lambda do |id, seen = []|
    return nil if seen.include?(id)

    target_of.key?(id) ? final_target.(target_of[id], seen + [id]) : id
  end
confirmed.each do |merge|
  merge["final_into"] = final_target.(merge["into"], [merge["from"]])
  merge["cycle"] = true if merge["final_into"].nil?
end

# Decisions that point at a cluster merged away follow it to the surviving one.
decisions.each do |d|
  if d["cluster_id"] && target_of.key?(d["cluster_id"]) && (final = final_target.(d["cluster_id"]))
    d["merged_cluster_id"] = d["cluster_id"]
    d["cluster_id"] = final
  end
  assigned = d["assigned_macro"]
  if assigned && target_of.key?(assigned["id"]) && (final = final_target.(assigned["id"]))
    d["assigned_macro"] = assigned.merge("id" => final, "merged_from" => assigned["id"])
  end
end

run_id = File.basename(dir)
IgnoredInksReview.write_json(
  File.join(dir, "decisions.json"),
  {
    "run_id" => run_id,
    "generated_at" => Time.now.utc.iso8601,
    "incomplete" => incomplete.uniq,
    "dangling_group_refs" => dangling,
    "invalid" => invalid,
    "merge_conflicts" => merge_conflicts,
    "groups" => groups,
    "merges" => merges,
    "decisions" => decisions
  }
)

summary = decisions.map { |d| d["verdict"] }.tally
verdict_kind =
  lambda { |verdict| IgnoredInksReview::CHANGE_VERDICTS.include?(verdict) ? "change" : verdict }
by_prompt_change =
  decisions
    .group_by { |d| d["ignored_vs_prompt_change"] }
    .transform_values { |group| group.map { |d| verdict_kind.(d["verdict"]) }.tally }
puts JSON.pretty_generate(
       "decisions" => decisions.size,
       "verdicts" => summary,
       "disputed" => decisions.count { |d| d["disputed"] },
       "human_overrides" => decisions.count { |d| d["source"] == "human" },
       "new_cluster_groups" => groups.size,
       "merges_confirmed" => confirmed.count { |m| !m["cycle"] },
       "merge_cycles" => confirmed.select { |m| m["cycle"] }.map { |m| m["id"] },
       "incomplete" => incomplete.uniq.size,
       "dangling_group_refs" => dangling,
       "invalid" => invalid,
       "merge_conflicts" => merge_conflicts,
       "verdicts_by_latest_ignore_vs_prompt_change" => by_prompt_change
     )
