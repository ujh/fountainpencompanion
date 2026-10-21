# Validates a subagent's output file against its input batch. Prints "OK" or a
# list of problems to send back to the subagent, and exits non-zero on errors.
#
#   ruby check.rb OUTPUT_FILE
require_relative "lib/common"

output = ARGV[0] or abort "Usage: check.rb OUTPUT_FILE"
input = output.sub(%r{/out-(\d+)\.json\z}, '/in-\1.jsonl')
stage = File.basename(File.dirname(output))
abort "Unknown stage #{stage}" unless IgnoredInksReview::STAGES.include?(stage)
abort "Missing output #{output}" unless File.exist?(output)

errors = []
rows =
  begin
    IgnoredInksReview.read_json(output)
  rescue JSON::ParserError => e
    puts "Invalid JSON: #{e.message}"
    exit 1
  end
unless rows.is_a?(Array)
  puts "Output must be a JSON array"
  exit 1
end

inputs = IgnoredInksReview.read_jsonl(input).to_h { |row| [row["id"], row] }
ids = rows.map { |row| row["id"] }
errors << "Missing ids: #{(inputs.keys - ids).join(", ")}" if (inputs.keys - ids).any?
errors << "Unexpected ids: #{(ids - inputs.keys).join(", ")}" if (ids - inputs.keys).any?
if ids.uniq.size != ids.size
  errors << "Duplicate ids: #{ids.tally.select { |_, n| n > 1 }.keys.join(", ")}"
end

def blank?(value) = value.nil? || (value.respond_to?(:empty?) && value.empty?)

def evidence_ok?(evidence)
  evidence.is_a?(Array) && evidence.any? &&
    evidence.all? do |e|
      e.is_a?(Hash) && e["url"].to_s.match?(%r{\A(https?://|db:)}) && !blank?(e["note"])
    end
end

assign_targets = []
group_refs = []
merge_refs = []

rows.each do |row|
  id = row["id"]
  candidate = inputs[id] || {}
  prefix = "id #{id}:"
  explanation = row.values_at("reason", "reasoning", "notes").compact
  if explanation.none? { |text| text.is_a?(String) && !text.strip.empty? } ||
       explanation.any? { |text| !text.is_a?(String) }
    errors << "#{prefix} reason/reasoning/notes must be a non-empty string"
  end

  case stage
  when "triage"
    unless IgnoredInksReview::TRIAGE_VERDICTS.include?(row["verdict"])
      errors << "#{prefix} verdict must be one of #{IgnoredInksReview::TRIAGE_VERDICTS.join("/")}"
    end
    if row["verdict"] == "keep_ignored" && !IgnoredInksReview::CATEGORIES.include?(row["category"])
      errors << "#{prefix} keep_ignored needs category in #{IgnoredInksReview::CATEGORIES.join("/")}"
    end
  when "research"
    verdict = row["verdict"]
    unless IgnoredInksReview::RESEARCH_VERDICTS.include?(verdict)
      errors << "#{prefix} verdict must be one of #{IgnoredInksReview::RESEARCH_VERDICTS.join("/")}"
    end
    unless %w[high medium low].include?(row["confidence"])
      errors << "#{prefix} confidence must be high/medium/low"
    end
    if verdict == "keep_ignored" && !IgnoredInksReview::CATEGORIES.include?(row["category"])
      errors << "#{prefix} keep_ignored needs category in #{IgnoredInksReview::CATEGORIES.join("/")}"
    end
    if IgnoredInksReview::CHANGE_VERDICTS.include?(verdict) && !evidence_ok?(row["evidence"])
      errors << "#{prefix} #{verdict} needs evidence: [{url, note}] with at least one entry (url is http(s)://... or db:...)"
    end
    case verdict
    when "assign"
      if row["cluster_id"].is_a?(Integer)
        assign_targets << [id, row["cluster_id"]]
      else
        errors << "#{prefix} assign needs integer cluster_id"
      end
    when "create"
      name = row["proposed_name"]
      unless name.is_a?(Hash) && !blank?(name["brand_name"]) && !blank?(name["ink_name"])
        errors << "#{prefix} create needs proposed_name {brand_name, line_name, ink_name}"
      end
      Array(row["group_with"]).each { |other| group_refs << [id, other] }
    when "unignore"
      unless candidate["assigned_macro"]
        errors << "#{prefix} unignore is only valid for clusters with assigned_macro"
      end
    end
  when "verify"
    unless IgnoredInksReview::VERIFY_VERDICTS.include?(row["verdict"])
      errors << "#{prefix} verdict must be one of #{IgnoredInksReview::VERIFY_VERDICTS.join("/")}"
    end
  when "merge"
    unless IgnoredInksReview::MERGE_VERDICTS.include?(row["verdict"])
      errors << "#{prefix} verdict must be one of #{IgnoredInksReview::MERGE_VERDICTS.join("/")}"
    end
    pair = [candidate["from"], candidate["into"]].sort
    if [row["from"], row["into"]].sort != pair
      errors << "#{prefix} from/into must be the input pair #{pair.join(" and ")} (either direction)"
    end
  end

  next unless row.key?("merge_suggestions")

  suggestions = row["merge_suggestions"]
  valid =
    suggestions.is_a?(Array) &&
      suggestions.all? do |m|
        m.is_a?(Hash) && m["from"].is_a?(Integer) && m["into"].is_a?(Integer) &&
          m["from"] != m["into"] && !blank?(m["reason"])
      end
  if valid
    suggestions.each { |m| merge_refs.push([id, m["from"]], [id, m["into"]]) }
  else
    errors << "#{prefix} merge_suggestions must be [{from: integer, into: integer, reason}] with from != into"
  end
end

macro_refs = assign_targets + merge_refs
if macro_refs.any?
  existing =
    IgnoredInksReview
      .query(
        "select id from macro_clusters where id = any($1::bigint[])",
        ["{#{macro_refs.map(&:last).uniq.join(",")}}"]
      )
      .map { |r| r["id"].to_i }
  macro_refs.each do |id, cluster_id|
    unless existing.include?(cluster_id)
      errors << "id #{id}: macro cluster #{cluster_id} does not exist"
    end
  end
end

if group_refs.any?
  known = IgnoredInksReview.candidates(File.dirname(File.dirname(output))).map { |c| c["id"] }
  group_refs.each do |id, other|
    unless known.include?(other)
      errors << "id #{id}: group_with #{other.inspect} is not an ignored micro cluster id"
    end
  end
end

if errors.empty?
  tally = rows.map { |r| r["verdict"] }.tally
  puts "OK #{tally.map { |k, v| "#{k}=#{v}" }.join(" ")}"
else
  puts errors
  exit 1
end
