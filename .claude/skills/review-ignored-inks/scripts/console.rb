# Generates the production scripts from RUN_DIR/decisions.json:
#
#   console/01-changes.rb       merges, then assign / create / unignore / unassign, plus their review logs
#   console/02-keep-NNN.rb      review logs only (keep_ignored, unsure), in chunks
#
#   ruby console.rb RUN_DIR [--chunk N]
#
# Refuses to run while decisions.json still has incomplete reviews.
require_relative "lib/common"

dir = IgnoredInksReview.run_dir(ARGV[0])
chunk_size = ARGV.index("--chunk") ? ARGV[ARGV.index("--chunk") + 1].to_i : 400
data = IgnoredInksReview.read_json(File.join(dir, "decisions.json"))
if data["incomplete"].any?
  abort "decisions.json has #{data["incomplete"].size} incomplete reviews; finish them first"
end
if data["dangling_group_refs"].any?
  abort "decisions.json has dangling group refs: #{data["dangling_group_refs"].inspect}"
end

template = File.read(File.join(__dir__, "console_template.rb"))

def console_entry(decision)
  {
    "id" => decision["id"],
    "name" => decision["name"],
    "verdict" => decision["verdict"],
    "category" => decision["category"],
    "reason" => decision["reason"].to_s[0, 500],
    "users" => decision["users"],
    "assigned_macro_id" => decision.dig("assigned_macro", "id"),
    "cluster_id" => decision["cluster_id"],
    "evidence" => decision["evidence"].to_a.map { |e| e["url"] },
    "source" => decision["source"]
  }.compact
end

decisions = data["decisions"]
change = ->(d) do
  IgnoredInksReview::CHANGE_VERDICTS.include?(d["verdict"]) ||
    (d["verdict"] == "keep_ignored" && d["assigned_macro"])
end

merge_units =
  (data["merges"] || [])
    .select { |m| m["verdict"] == "confirm" && !m["cycle"] }
    .map { |m| { "merge" => m.slice("id", "from", "into", "notes", "source") } }
change_units =
  merge_units +
    data["groups"].map do |key, group|
      {
        "group" => key,
        "members" => group["ids"].map { |id| console_entry(decisions.find { |d| d["id"] == id }) }
      }
    end
change_units +=
  decisions.select { |d| change.(d) && d["verdict"] != "create" }.map { |d| console_entry(d) }
keep_units = decisions.reject { |d| change.(d) }.map { |d| console_entry(d) }

def render(template, run_id, part, summary, units)
  json = "[\n" + units.map { |u| "    #{JSON.generate(u)}" }.join(",\n") + "\n    ]"
  # Block form, so backslashes in the JSON are not read as substitution escapes.
  template
    .gsub("__RUN_ID__") { run_id }
    .sub("__PART__") { part }
    .sub("__SUMMARY__") { summary }
    .sub("__DECISIONS__") { json }
end

console_dir = File.join(dir, "console")
FileUtils.rm_rf(console_dir)
FileUtils.mkdir_p(console_dir)

written = []
if change_units.any?
  verdicts =
    change_units
      .flat_map { |u| u["members"] || [u] }
      .map { |u| u["merge"] ? "merge" : u["verdict"] }
      .tally
  path = File.join(console_dir, "01-changes.rb")
  File.write(
    path,
    render(
      template,
      data["run_id"],
      "01-changes",
      verdicts.map { |k, v| "#{k} #{v}" }.join(", "),
      change_units
    )
  )
  written << path
end
keep_units
  .each_slice(chunk_size)
  .with_index(1) do |units, index|
    verdicts = units.map { |u| u["verdict"] }.tally
    part = format("02-keep-%03d", index)
    path = File.join(console_dir, "#{part}.rb")
    File.write(
      path,
      render(
        template,
        data["run_id"],
        part,
        "review logs only: #{verdicts.map { |k, v| "#{k} #{v}" }.join(", ")}",
        units
      )
    )
    written << path
  end

written.each { |path| puts "#{path} (#{File.size(path) / 1024} KB)" }
