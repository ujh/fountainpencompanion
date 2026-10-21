# Renders RUN_DIR/decisions.json into Markdown files for review in revdiff:
#
#   review/proposals.md     changes, disputed and unsure items, researched keeps
#   review/keep-ignored.md  triage keeps, one line each, grouped by category
#   review/line-map.json    which lines belong to which micro cluster id
#
#   ruby render.rb RUN_DIR
require_relative "lib/common"

dir = IgnoredInksReview.run_dir(ARGV[0])
data = IgnoredInksReview.read_json(File.join(dir, "decisions.json"))
decisions = data["decisions"]
by_id = decisions.to_h { |d| [d["id"], d] }
merges = data["merges"] || []
macro_ids = decisions.flat_map { |d| [d["cluster_id"], d.dig("verifier", "suggested_cluster_id")] }
macro_ids += merges.flat_map { |m| [m["from"], m["into"]] }
macro_ids = macro_ids.compact.uniq
macros = IgnoredInksReview.macro_details(macro_ids).to_h { |m| [m["id"], m] }

class Doc
  attr_reader :lines, :map

  def initialize(file)
    self.file = file
    self.lines = []
    self.map = []
  end

  def <<(line)
    lines << line
    self
  end

  # Lines added inside the block are attributed to the given ids.
  def entry(ids)
    start = lines.size + 1
    yield
    map << { "file" => file, "from" => start, "to" => lines.size, "ids" => Array(ids) }
  end

  def to_s = lines.join("\n") + "\n"

  private

  attr_writer :lines, :map
  attr_accessor :file
end

def colours(d) = d["colors"].any? ? " · #{d["colors"].first(3).join(" ")}" : ""

def users(d) = "#{d["users"]} user#{"s" unless d["users"] == 1}"

def evidence_lines(doc, d)
  d["evidence"].to_a.each { |e| doc << "  - evidence: #{e["url"]} — #{e["note"]}" }
end

def detail_lines(doc, d, macros)
  doc << "  - names: #{d["names"].join(" | ")}"
  doc << "  - #{users(d)}, #{d["inks"]} inks#{colours(d)}"
  meta = ["confidence: #{d["confidence"] || "-"}", "source: #{d["source"]}"]
  meta << "flags: #{d["flags"].join(", ")}" if d["flags"].to_a.any?
  doc << "  - #{meta.join(" · ")}"
  doc << "  - reasoning: #{d["reason"]}"
  evidence_lines(doc, d)
  if (verifier = d["verifier"])
    suggestion = [
      verifier["suggested_verdict"],
      verifier["suggested_cluster_id"] && macro_line(macros[verifier["suggested_cluster_id"]])
    ].compact
    doc << "  - verifier: #{verifier["verdict"]}#{" → suggests #{suggestion.join(" ")}" if suggestion.any?} — #{verifier["notes"]}"
  end
  doc << "  - human note: #{d["human_note"]}" if d["human_note"]
  doc << "  - clusterer history: #{d["history"].join("; ")}" if d["history"].any?
end

def macro_line(macro)
  return "(unknown cluster)" unless macro

  "##{macro["id"]} #{macro["name"]} (#{macro["users"]} users#{", #{macro["color"]}" unless macro["color"].to_s.empty?}; " \
    "also: #{macro["synonyms"].first(4).join(" | ")})"
end

proposals = Doc.new("proposals.md")
keeps = Doc.new("keep-ignored.md")

counts = decisions.map { |d| d["verdict"] }.tally
proposals << "# Ignored inks review — run #{data["run_id"]}"
proposals << ""
proposals << "Annotate any line of an entry to change it, e.g. `reject` / `keep ignored`, `assign 1234`,"
proposals << "`create`, `group with 567`, `unsure`, or a question. Entries without annotations are applied"
proposals << "as shown. Disputed and unsure entries stay ignored unless annotated."
proposals << ""
proposals << "Totals: #{counts.map { |k, v| "#{k} #{v}" }.join(", ")} · disputed #{decisions.count { |d| d["disputed"] }}"
if data["incomplete"].any?
  proposals << "Incomplete (not reviewed this run): #{data["incomplete"].size}"
end
proposals << ""

if merges.any?
  confirmed, rejected = merges.partition { |m| m["verdict"] == "confirm" }
  merged_away = confirmed.map { |m| m["from"] }
  rejected =
    rejected.reject { |m| merged_away.include?(m["from"]) || merged_away.include?(m["into"]) }
  proposals << "## Merge duplicate clusters (#{confirmed.size})"
  proposals << ""
  proposals << "Moves micro clusters, reviews and review submissions into the kept cluster and deletes the other."
  proposals << "Annotate `reject` to keep both, or `swap` to keep the other one."
  proposals << ""
  confirmed.each do |m|
    proposals.entry(m["id"]) do
      cycle = m["cycle"] ? " · SKIPPED: merge cycle" : ""
      proposals << "### #{m["id"]} · merge #{macro_line(macros[m["from"]])}"
      proposals << "  - into #{macro_line(macros[m["into"]])}#{cycle}"
      if m["final_into"] && m["final_into"] != m["into"]
        proposals << "  - final target: ##{m["final_into"]}"
      end
      proposals << "  - verifier: #{m["notes"]}"
      proposals << "  - human note: #{m["human_note"]}" if m["human_note"]
    end
    proposals << ""
  end
  if rejected.any?
    proposals << "## Merges rejected by the verifier — not merged unless annotated (#{rejected.size})"
    proposals << ""
    rejected.each do |m|
      proposals.entry(m["id"]) do
        proposals << "- #{m["id"]} · ##{m["from"]} #{macros.dig(m["from"], "name")} / ##{m["into"]} #{macros.dig(m["into"], "name")} — #{m["notes"]}"
      end
    end
    proposals << ""
  end
end

assigned = decisions.select { |d| d["assigned_macro"] }
if assigned.any?
  proposals << "## Ignored but still assigned to a macro cluster (#{assigned.size})"
  proposals << ""
  proposals << "keep_ignored unassigns the micro cluster (and deletes the macro cluster if that leaves it empty"
  proposals << "without reviews or description); unignore keeps the current assignment; assign moves it."
  proposals << ""
  assigned.each do |d|
    proposals.entry(d["id"]) do
      current = d["assigned_macro"]
      action =
        case d["verdict"]
        when "unignore"
          "UNIGNORE, keep in ##{current["id"]}"
        when "assign"
          "MOVE to #{macro_line(macros[d["cluster_id"]])}"
        when "create"
          "MOVE to new cluster #{d["group"]} (see Create new clusters)"
        when "keep_ignored"
          "UNASSIGN from ##{current["id"]}, stays ignored"
        else
          "NO CHANGE (#{d["verdict"]}#{", disputed" if d["disputed"]})"
        end
      proposals << "### MC #{d["id"]} · #{d["name"]} → #{action}"
      proposals << "  - currently in: ##{current["id"]} #{current["name"]} (#{current["other_micro_clusters"]} other micro clusters)"
      detail_lines(proposals, d, macros)
    end
    proposals << ""
  end
end

rest = decisions.reject { |d| d["assigned_macro"] }

assigns = rest.select { |d| d["verdict"] == "assign" }
proposals << "## Assign to an existing cluster (#{assigns.size})"
proposals << ""
assigns.each do |d|
  proposals.entry(d["id"]) do
    proposals << "### MC #{d["id"]} · #{d["name"]} → #{macro_line(macros[d["cluster_id"]])}"
    detail_lines(proposals, d, macros)
  end
  proposals << ""
end

groups = data["groups"]
proposals << "## Create new clusters (#{groups.size})"
proposals << ""
proposals << "The new cluster's name is computed from the users' entries, as for any cluster; the proposed"
proposals << "name shows what the researcher found. Fix names afterwards in the admin UI if needed."
proposals << ""
groups.each do |key, group|
  members = group["ids"].map { |id| by_id[id] }
  name = group["proposed_name"] || {}
  proposals.entry(group["ids"]) do
    proposals << "### #{key} · new cluster “#{[name["brand_name"], name["line_name"], name["ink_name"]].reject { |p| p.to_s.empty? }.join(" ")}” from MC #{group["ids"].join(", ")}"
    members.each do |d|
      proposals << "- MC #{d["id"]} · #{d["name"]}"
      detail_lines(proposals, d, macros)
    end
  end
  proposals << ""
end

disputed = rest.select { |d| d["disputed"] }
proposals << "## Disputed by the verifier — stay ignored unless annotated (#{disputed.size})"
proposals << ""
disputed.each do |d|
  target = d["proposed_verdict"] == "assign" ? " #{macro_line(macros[d["cluster_id"]])}" : ""
  proposals.entry(d["id"]) do
    proposals << "### MC #{d["id"]} · #{d["name"]} · researcher proposed #{d["proposed_verdict"]}#{target}"
    detail_lines(proposals, d, macros)
  end
  proposals << ""
end

unsure = rest.select { |d| d["verdict"] == "unsure" && !d["disputed"] }
proposals << "## Unsure — stay ignored, re-checked in a later run (#{unsure.size})"
proposals << ""
unsure.each do |d|
  proposals.entry(d["id"]) do
    proposals << "### MC #{d["id"]} · #{d["name"]}"
    detail_lines(proposals, d, macros)
  end
  proposals << ""
end

researched_keeps = rest.select { |d| d["verdict"] == "keep_ignored" && d["source"] != "triage" }
proposals << "## Researched and kept ignored (#{researched_keeps.size})"
proposals << ""
researched_keeps.each do |d|
  proposals.entry(d["id"]) do
    proposals << "- MC #{d["id"]} · #{d["name"]} · #{users(d)} · #{d["category"]} — #{d["reason"]}"
  end
end

triage_keeps = rest.select { |d| d["verdict"] == "keep_ignored" && d["source"] == "triage" }
keeps << "# Kept ignored by triage — run #{data["run_id"]} (#{triage_keeps.size})"
keeps << ""
keeps << "Annotate a line to send that ink to research or to change it; everything else stays ignored."
triage_keeps
  .group_by { |d| d["category"] }
  .sort_by { |_, ds| -ds.size }
  .each do |category, ds|
    keeps << ""
    keeps << "## #{category} (#{ds.size})"
    keeps << ""
    ds
      .sort_by { |d| [-d["users"], d["name"].downcase] }
      .each do |d|
        keeps.entry(d["id"]) do
          keeps << "- MC #{d["id"]} · #{d["name"]} · #{users(d)} — #{d["reason"]}"
        end
      end
  end

review_dir = File.join(dir, "review")
FileUtils.mkdir_p(review_dir)
File.write(File.join(review_dir, "proposals.md"), proposals.to_s)
File.write(File.join(review_dir, "keep-ignored.md"), keeps.to_s)
IgnoredInksReview.write_json(File.join(review_dir, "line-map.json"), proposals.map + keeps.map)
puts "Wrote #{review_dir}/proposals.md (#{proposals.lines.size} lines) and keep-ignored.md (#{keeps.lines.size} lines)"
