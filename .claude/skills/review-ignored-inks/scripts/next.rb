# Prints the next batch to hand to a subagent as JSON, creating its input file
# when needed. Stages run in order: triage -> research -> verify -> review.
# An input file without an output (e.g. a crashed subagent) is handed out again.
#
#   ruby next.rb RUN_DIR [--size N]
require_relative "lib/common"

dir = IgnoredInksReview.run_dir(ARGV[0])
size_override = ARGV.index("--size") && ARGV[ARGV.index("--size") + 1].to_i

pending =
  IgnoredInksReview.pending(dir).sort_by { |c| [c["simplified"][0], c["simplified"][2], c["id"]] }
triage = IgnoredInksReview.results(dir, "triage")
research = IgnoredInksReview.results(dir, "research")
verify = IgnoredInksReview.results(dir, "verify")
merges = IgnoredInksReview.results(dir, "merge")

def last_log_summary(candidate)
  log = candidate["clusterer_logs"].first
  return nil unless log

  [
    log["created"],
    log["action"],
    log["follow_up_action"] && "checker:#{log["follow_up_action"]}",
    log["state"],
    log["explanation"].to_s[0, 160]
  ].compact.join(" | ")
end

def triage_view(candidate)
  {
    "id" => candidate["id"],
    "names" =>
      candidate["names"].map { |n| [n["brand_name"], n["line_name"], n["ink_name"], n["users"]] },
    "users" => candidate["users"],
    "colors" => candidate["colors"].first(2),
    "brand_known" => candidate["brand_known"],
    "brand_stats" => candidate["brand_stats"],
    "same_brand_and_ink" => candidate["same_brand_and_ink"],
    "same_ink_other_brand" => candidate["same_ink_other_brand"].first(3),
    "last_clusterer_log" => last_log_summary(candidate)
  }
end

# Clusters that skip triage: the data already says there is something to look at.
def forced_research?(candidate)
  candidate["assigned_macro"] || candidate["same_brand_and_ink"].any?
end

# Duplicate macro cluster pairs suggested by research or verify, plus any the
# orchestrator added to merge-seeds.json ([{from, into, reason}]).
def merge_pairs(dir, *stage_results)
  seeds_path = File.join(dir, "merge-seeds.json")
  seeds =
    File.exist?(seeds_path) ? IgnoredInksReview.read_json(seeds_path).map { |m| [nil, m] } : []
  suggestions =
    stage_results
      .flat_map(&:values)
      .flat_map { |row| Array(row["merge_suggestions"]).map { |m| [row["id"], m] } }
  (suggestions + seeds)
    .group_by { |_, m| [m["from"], m["into"]].sort }
    .map do |(low, high), entries|
      first = entries.first.last
      {
        "id" => "m#{low}-#{high}",
        "from" => first["from"],
        "into" => first["into"],
        "reasons" =>
          entries
            .map { |source, m| [source && "MC #{source}", m["reason"]].compact.join(": ") }
            .uniq,
        "suggested_by" => entries.filter_map(&:first).uniq
      }
    end
end

needs = {
  "triage" => pending.reject { |c| triage.key?(c["id"]) || forced_research?(c) },
  "research" =>
    pending.select do |c|
      (forced_research?(c) || triage.dig(c["id"], "verdict") == "research") &&
        !research.key?(c["id"])
    end,
  "verify" =>
    pending.select do |c|
      IgnoredInksReview::CHANGE_VERDICTS.include?(research.dig(c["id"], "verdict")) &&
        !verify.key?(c["id"])
    end,
  "merge" => merge_pairs(dir, research, verify, merges).reject { |pair| merges.key?(pair["id"]) }
}

# Stages are ordered, so research starts once triage is done and verify once
# research is.
stage = IgnoredInksReview::STAGES.find { |s| needs[s].any? }

unless stage
  puts JSON.pretty_generate(
         "stage" => "review",
         "message" => "All stages done. Run finalize.rb then render.rb."
       )
  exit
end

open_batch =
  IgnoredInksReview
    .batch_files(dir, stage)
    .find { |f| !File.exist?(IgnoredInksReview.output_for(f)) }
input =
  open_batch ||
    begin
      number = IgnoredInksReview.batch_files(dir, stage).size + 1
      path = File.join(dir, stage, format("in-%03d.jsonl", number))
      batch = needs[stage].first(size_override || IgnoredInksReview::BATCH_SIZES[stage])
      rows =
        case stage
        when "triage"
          batch.map { |c| triage_view(c) }
        when "research"
          batch.map { |c| c.merge("triage" => triage[c["id"]]) }
        when "verify"
          batch.map { |c| c.merge("triage" => triage[c["id"]], "proposal" => research[c["id"]]) }
        when "merge"
          details =
            IgnoredInksReview
              .macro_details(batch.flat_map { |p| [p["from"], p["into"]] }.uniq)
              .to_h { |m| [m["id"], m] }
          batch.map { |p| p.merge("clusters" => [details[p["from"]], details[p["into"]]].compact) }
        end
      IgnoredInksReview.write_jsonl(path, rows)
      path
    end

batch_count = IgnoredInksReview.read_jsonl(input).size
puts JSON.pretty_generate(
       "stage" => stage,
       "input" => input,
       "output" => IgnoredInksReview.output_for(input),
       "batch_size" => batch_count,
       "remaining_in_stage_after_this_batch" => needs[stage].size - batch_count,
       "progress" => {
         "pending" => pending.size,
         "triaged" => triage.size,
         "researched" => research.size,
         "verified" => verify.size,
         "merges_checked" => merges.size
       }
     )
